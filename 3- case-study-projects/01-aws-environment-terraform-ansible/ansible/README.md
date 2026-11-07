# Ansible Configuration Management for Private AWS EC2 Instances Using Systems Manager (SSM)

> **Project:** End-to-End Enterprise AWS Environment Provisioning using
> Terraform and Ansible\
> **Region:** `us-east-1`\
> **AWS CLI profile:** `terraform-lab`\
> **Operating system:** Ubuntu 22.04 LTS on EC2\
> **Ansible controller:** Ubuntu workstation\
> **Connection method:** AWS Systems Manager Session Manager (no inbound
> SSH required)

------------------------------------------------------------------------

## Table of contents

1.  [Architecture and objective](#1-architecture-and-objective)
2.  [How Ansible connects without
    SSH](#2-how-ansible-connects-without-ssh)
3.  [Prerequisites](#3-prerequisites)
4.  [AWS-side prerequisites](#4-aws-side-prerequisites)
5.  [Prepare the Ubuntu Ansible
    controller](#5-prepare-the-ubuntu-ansible-controller)
6.  [Create the S3 transfer bucket](#6-create-the-s3-transfer-bucket)
7.  [Create the Ansible project
    structure](#7-create-the-ansible-project-structure)
8.  [Configure AWS dynamic
    inventory](#8-configure-aws-dynamic-inventory)
9.  [Configure the SSM connection](#9-configure-the-ssm-connection)
10. [Discover and verify the EC2
    inventory](#10-discover-and-verify-the-ec2-inventory)
11. [Test SSM connectivity](#11-test-ssm-connectivity)
12. [Run a first Ansible playbook](#12-run-a-first-ansible-playbook)
13. [Organize the four server roles](#13-organize-the-four-server-roles)
14. [Troubleshooting](#14-troubleshooting)
15. [Security recommendations](#15-security-recommendations)
16. [Cost considerations](#16-cost-considerations)
17. [Operational checklist](#17-operational-checklist)
18. [Official documentation](#18-official-documentation)

------------------------------------------------------------------------

## 1. Architecture and objective

This guide configures four EC2 instances in a private subnet using
Ansible, while keeping SSH (TCP/22) closed.

### Current workshop architecture

  --------------------------------------------------------------------------
  Component         EC2 Name tag         Network placement Purpose
  ----------------- -------------------- ----------------- -----------------
  Application `ec2-tomcat-01` Private subnet Java application on Apache Tomcat

  Database `ec2-mariadb-01` Private subnet MariaDB database

  Messaging `ec2-rabbitmq-01` Private subnet    RabbitMQ message broker

  Cache `ec2-memcached-01`   Private subnet    Memcached cache

  --------------------------------------------------------------------------

Existing AWS network design:

-   AWS Region: `us-east-1`
-   VPC CIDR: `10.0.0.0/16`
-   Public subnet A: `10.0.1.0/24` in `us-east-1a`
-   Public subnet B: `10.0.3.0/24` in `us-east-1b`
-   Private subnet: `10.0.2.0/24` in `us-east-1a`
-   Internet-facing Application Load Balancer (ALB): public subnets A
    and B
-   NAT Gateway: public subnet, with an Elastic IP
-   Four Linux EC2 instances: private subnet, without public IP
    addresses

### Traffic design

``` text
                         Internet
                            |
                     Internet Gateway
                            |
             +--------------+--------------+
             |                             |
       Public subnet A               Public subnet B
       us-east-1a                    us-east-1b
             |                             |
             +------ Application Load -----+
                    Balancer (HTTP/80)
                            |
                  VPC private networking
                            |
                    Private subnet
                     10.0.2.0/24
                            |
                  Tomcat EC2 (8080)
                     /     |      \
                MariaDB  RabbitMQ  Memcached
                 3306      5672      11211

Private subnet default route (0.0.0.0/0)
                            |
                       NAT Gateway
                            |
                     Internet Gateway
                            |
                         Internet
```

The ALB-to-Tomcat connection uses private VPC routing. It does **not**
pass through the NAT Gateway. The NAT Gateway is for outbound
connections initiated by private instances, such as downloading Ubuntu
packages or reaching public AWS service endpoints.

### Objective

After completing this guide, Ansible running on the Ubuntu workstation
should be able to:

-   Discover the four EC2 instances using AWS dynamic inventory.
-   Connect to them using the `amazon.aws.aws_ssm` connection plugin.
-   Run Ansible tasks without SSH access or public IP addresses.
-   Configure each server independently using playbooks and roles.

------------------------------------------------------------------------

## 2. How Ansible connects without SSH

By default, Ansible uses SSH to manage Linux hosts. The AWS Systems
Manager connection plugin changes the transport: Ansible invokes Session
Manager to communicate with the managed EC2 instance.

The main components are:

1.  **Ansible controller:** Your Ubuntu workstation, where Ansible and
    the AWS CLI are installed.
2.  **AWS CLI credentials:** Your `terraform-lab` AWS IAM Identity
    Center (SSO) profile.
3.  **Session Manager plugin:** A local executable required by the AWS
    CLI/Ansible SSM connection.
4.  **SSM Agent:** Runs on each managed EC2 instance and maintains
    outbound communication with Systems Manager.
5.  **EC2 IAM instance profile:** Grants the instance permission to
    communicate with Systems Manager.
6.  **S3 transfer bucket:** The Ansible SSM connection plugin uses S3 to
    transfer its temporary module and file payloads.
7.  **Network connectivity:** The workstation and EC2 instances need
    access to the relevant AWS endpoints.

No inbound SSH rule is needed for this method.

> **Important:** SSM is not the same as SSH. Do not set `ansible_user`
> or configure an SSH private key for the SSM connection. The SSM
> connection targets the EC2 instance ID.

------------------------------------------------------------------------

## 3. Prerequisites

### 3.1 AWS resources

Confirm that the following already exist:

-   VPC and subnets.
-   Internet Gateway and public routes.
-   NAT Gateway and its Elastic IP.
-   Private subnet route `0.0.0.0/0` pointing to the NAT Gateway.
-   Four running Ubuntu 22.04 EC2 instances.
-   IAM role and instance profile attached to each EC2 instance.
-   Security groups allowing only the required application traffic.

### 3.2 Workstation software

The Ubuntu workstation needs:

-   AWS CLI v2.
-   An AWS IAM Identity Center profile named `terraform-lab`.
-   Ansible.
-   Python 3 and `pip`.
-   `boto3` and `botocore`.
-   Ansible collection `amazon.aws`.
-   AWS Systems Manager Session Manager plugin.

### 3.3 Verify AWS CLI authentication

``` bash
aws --version
aws sso login --profile terraform-lab

aws sts get-caller-identity \
  --profile terraform-lab \
  --region us-east-1
```

The identity command should return the AWS account and the IAM role/user
associated with the SSO session. Confirm that it is the intended
workshop account before continuing.

------------------------------------------------------------------------

## 4. AWS-side prerequisites

### 4.1 EC2 instance IAM role

Each EC2 instance must have an IAM instance profile with the AWS-managed
policy:

`AmazonSSMManagedInstanceCore`

The existing Terraform resources in this workshop are:

``` text
aws_iam_role.my_ec2_ssm
aws_iam_role_policy_attachment.my_ec2_ssm_core
aws_iam_instance_profile.my_ec2_ssm_instance_profile
```

Check the Terraform configuration and confirm that the role is attached
to the instance profile and that the policy attachment references
`AmazonSSMManagedInstanceCore`.

The instance profile must be attached to all four EC2 instances. The
role on the EC2 instances is separate from the permissions assigned to
the human/operator SSO identity.

### 4.2 Operator SSO permissions

The SSO identity used by the Ansible controller needs permission to:

-   Describe EC2 instances for dynamic inventory.
-   Start, open, and terminate SSM sessions.
-   Use the S3 transfer bucket (list bucket and upload/download/delete
    the objects required by the plugin).
-   Perform any additional SSM message-channel operations required by
    the Session Manager workflow.

Use a least-privilege IAM Identity Center permission set. Do not assume
that attaching `AmazonSSMManagedInstanceCore` to the EC2 role grants the
operator permission to start sessions or use S3.

The exact S3 permissions depend on the bucket and plugin workflow.
Review the current Ansible SSM connection plugin documentation and its
required permissions before creating a production policy. Avoid granting
broad administrator access solely to make the connection work.

### 4.3 Network connectivity

The EC2 instances are private and have no public IP addresses. They need
outbound HTTPS (TCP/443) access to the Systems Manager endpoints. With
the current architecture, the NAT Gateway can provide this access.

The instances also need access to the S3 endpoint used for Ansible
transfers. This can be provided through NAT, or through an S3 VPC
endpoint with appropriate endpoint and bucket policies.

The workstation also needs outbound access to AWS APIs, SSM, and the S3
bucket.

A NAT Gateway is an AWS-managed service. It does not require an EC2
instance in a public subnet.

### 4.4 Confirm the private subnet route

``` bash
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-03245f06e881eeaf7" \
  --region us-east-1 \
  --query 'RouteTables[].Routes' \
  --output table
```

Confirm there is a default route to the NAT Gateway, in addition to the
local VPC route.

------------------------------------------------------------------------

## 5. Prepare the Ubuntu Ansible controller

### 5.1 Install Ansible

Check whether Ansible is installed:

``` bash
ansible --version
```

If it is not installed, use a Python virtual environment to avoid
conflicts with Ubuntu's system-managed Python packages:

``` bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip unzip curl

mkdir -p ~/aws-workshop
cd ~/aws-workshop

python3 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
python -m pip install ansible boto3 botocore
```

For future sessions, activate the environment before running Ansible:

``` bash
source ~/aws-workshop/.venv/bin/activate
```

### 5.2 Install the AWS Ansible collection

``` bash
ansible-galaxy collection install amazon.aws
```

Verify:

``` bash
ansible-galaxy collection list | grep amazon.aws
```

The `amazon.aws` collection provides the AWS EC2 dynamic inventory
plugin and the SSM connection plugin.

### 5.3 Install the AWS Session Manager plugin

Install the Session Manager plugin using the official AWS instructions
for your Ubuntu architecture:

https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-linux.html

Verify that the executable is available:

``` bash
session-manager-plugin
```

The command may print usage information or a message indicating that the
plugin was installed. It should not return `command not found`.

### 5.4 Confirm the local AWS profile

``` bash
aws configure list --profile terraform-lab
aws sts get-caller-identity --profile terraform-lab --region us-east-1
```

Do not put SSO passwords, access keys, or secret keys in Ansible
inventory or playbooks.

------------------------------------------------------------------------

## 6. Create the S3 transfer bucket

The Ansible SSM connection plugin uses an S3 bucket to transfer
temporary files between the controller and managed instances.

### 6.1 Choose a globally unique bucket name

S3 bucket names are globally unique. The following creates a name using
the AWS account ID and a random suffix:

``` bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

BUCKET_NAME="ansible-ssm-${ACCOUNT_ID}-us-east-1-$(date +%s)"

echo "$BUCKET_NAME"
```

Review the generated name before creating the bucket.

### 6.2 Create the bucket

For `us-east-1`, use:

``` bash
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region us-east-1 \
```

Save the bucket name in your project notes or local environment. Do not
commit account-specific bucket names if you prefer to keep the
repository reusable.

### 6.3 Block public access

``` bash
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --region us-east-1
```

### 6.4 Enable default encryption

``` bash
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --region us-east-1
```

### 6.5 Verify the bucket

``` bash
aws s3api head-bucket \
  --bucket "$BUCKET_NAME" \
  --region us-east-1

aws s3api get-public-access-block \
  --bucket "$BUCKET_NAME" \
  --region us-east-1
```

### 6.6 Cost and lifecycle

Creating an empty S3 bucket does not incur a bucket-creation fee.
Charges can apply for stored data, requests, retrieval, and data
transfer according to the applicable AWS pricing and Free Tier/credit
eligibility.

For this workshop, the transfer bucket should be small. You can add a
lifecycle rule to expire temporary objects after a short retention
period, such as 7 days, after confirming that this will not interfere
with active Ansible runs. Do not configure an aggressive lifecycle rule
that deletes objects during a playbook execution.

------------------------------------------------------------------------

## 7. Create the Ansible project structure

Create the working directory:

``` bash
mkdir -p ~/aws-workshop/ansible
cd ~/aws-workshop/ansible
```

Recommended structure:

``` text
ansible/
├── ansible.cfg
├── aws_ec2.yml
├── requirements.yml
├── group_vars/
│   └── all.yml
├── playbooks/
│   ├── connectivity-test.yml
│   ├── common.yml
│   ├── tomcat.yml
│   ├── mariadb.yml
│   ├── rabbitmq.yml
│   └── memcached.yml
└── roles/
    ├── common/
    │   └── tasks/
    │       └── main.yml
    ├── tomcat/
    │   ├── tasks/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   └── templates/
    ├── mariadb/
    │   └── tasks/
    │       └── main.yml
    ├── rabbitmq/
    │   └── tasks/
    │       └── main.yml
    └── memcached/
        └── tasks/
            └── main.yml
```

Create the directories:

``` bash
mkdir -p group_vars playbooks
mkdir -p roles/{common,tomcat,mariadb,rabbitmq,memcached}/{tasks,handlers,templates}
```

### 7.1 Install collection dependencies from a file

Create `requirements.yml`:

``` yaml
---
collections:
  - name: amazon.aws
```

Install:

``` bash
ansible-galaxy collection install -r requirements.yml
```

------------------------------------------------------------------------

## 8. Configure AWS dynamic inventory

Dynamic inventory lets Ansible query AWS for EC2 instances instead of
maintaining a static list of IP addresses.

This file is an Ansible AWS EC2 Dynamic Inventory configuration.

Its purpose is to allow Ansible to automatically discover your four EC2 instances in AWS instead of manually maintaining their IP addresses in an inventory file.

In your AWS project, thsis is particularly useful because:
- All four EC2 instances are in a private subnet.
- They don't have public IP addresses.
- You are using AWS Systems Manager (SSM) instead of SSH.
- Ansible can discover the instances using their AWS tags.
- You can organize the instances into groups based on their roles (Tomcat, MariaDB, RabbitMQ, and Memcached).

Create `aws_ec2.yml` in the project root:

``` yaml
---
plugin: amazon.aws.aws_ec2

regions:
  - us-east-1

filters:
  instance-state-name: running
  tag:Name:
    - ec2-tomcat-01
    - ec2-mariadb-01
    - ec2-rabbitmq-01
    - ec2-memcached-01

hostnames:
  - instance-id

keyed_groups:
  - key: tags.Name
    prefix: name
    separator: "_"
```

This inventory uses the EC2 instance ID as the inventory hostname and
creates groups from the `Name` tag. For example, a host tagged
`ec2-tomcat-01` will be placed in a group named `name_ec2_tomcat_01`.

The dynamic inventory plugin uses the AWS credentials available to the
controller. The SSO profile must be logged in before running inventory
commands.

Test the inventory plugin:

``` bash
export AWS_REGION=us-east-1
ansible-inventory -i aws_ec2.yml --graph
```

If you get a plugin parsing error, check that the `amazon.aws`
collection is installed and that the inventory file is named with the
expected `.aws_ec2.yml` or `.yml` suffix. The explicit
`plugin: amazon.aws.aws_ec2` declaration is required.

------------------------------------------------------------------------

## 9. Configure the SSM connection

Create `group_vars/all.yml`:

``` yaml
---
ansible_connection: amazon.aws.aws_ssm
ansible_aws_ssm_region: us-east-1
ansible_aws_ssm_profile: terraform-lab
ansible_aws_ssm_bucket_name: REPLACE_WITH_YOUR_BUCKET_NAME

ansible_become: true
```

Replace `REPLACE_WITH_YOUR_BUCKET_NAME` with the bucket created in Step
6.

### Important configuration notes

-   `ansible_connection` selects the AWS SSM connection plugin instead
    of SSH.
-   `ansible_aws_ssm_region` is the AWS region containing the instances.
-   `ansible_aws_ssm_profile` identifies the AWS CLI profile used by the
    controller.
-   `ansible_aws_ssm_bucket_name` is the S3 bucket used for temporary
    transfer files.
-   `ansible_become: true` asks Ansible to use privilege escalation for
    tasks that need root privileges.

Do not add `ansible_user: ubuntu` just because the instances run Ubuntu.
The SSM connection plugin does not use SSH in the normal way. If
privilege escalation fails, inspect the SSM session's operating-system
user and the plugin's current documentation before changing the become
settings.

### 9.1 Optional ansible.cfg

Create `ansible.cfg`:

``` ini
[defaults]
inventory = ./aws_ec2.yml
host_key_checking = False
retry_files_enabled = False
interpreter_python = auto_silent
timeout = 60
```

`host_key_checking` is an SSH-specific setting and is not needed for
SSM; it is included only to avoid confusion if SSH is later used for a
separate inventory. You may omit it entirely in an SSM-only project.

Do not store passwords, access keys, or SSO tokens in this file.

------------------------------------------------------------------------

## 10. Discover and verify the EC2 inventory

### 10.1 Log in to AWS SSO

``` bash
aws sso login --profile terraform-lab
export AWS_PROFILE=terraform-lab
export AWS_REGION=us-east-1
```

### 10.2 Display all discovered hosts

``` bash
ansible-inventory -i aws_ec2.yml --list
```

Or display a compact graph:

``` bash
ansible-inventory -i aws_ec2.yml --graph
```

Expected logical inventory:

``` text
@all:
  |--@ungrouped:
  |--@name_ec2_tomcat_01:
  |  |--i-xxxxxxxxxxxxxxxxx
  |--@name_ec2_mariadb_01:
  |  |--i-xxxxxxxxxxxxxxxxx
  |--@name_ec2_rabbitmq_01:
  |  |--i-xxxxxxxxxxxxxxxxx
  |--@name_ec2_memcached_01:
  |  |--i-xxxxxxxxxxxxxxxxx
```

The actual instance IDs will be different.

### 10.3 Verify AWS sees all four running instances

``` bash
aws ec2 describe-instances \
  --filters \
    "Name=instance-state-name,Values=running" \
    "Name=tag:Name,Values=ec2-tomcat-01,ec2-mariadb-01,ec2-rabbitmq-01,ec2-memcached-01" \
  --region us-east-1 \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,State:State.Name,PrivateIP:PrivateIpAddress,Subnet:SubnetId,AZ:Placement.AvailabilityZone}' \
  --output table
```

Confirm the instances are running and have private IP addresses in the
intended private subnet.

------------------------------------------------------------------------

## 11. Test SSM connectivity

### 11.1 Check SSM registration

``` bash
aws ssm describe-instance-information \
  --region us-east-1 \
  --query 'InstanceInformationList[].{InstanceId:InstanceId,PingStatus:PingStatus,Platform:PlatformName,AgentVersion:AgentVersion}' \
  --output table
```

Wait for all four EC2 instances to register. Their `PingStatus` should
be `Online`.

If an instance does not appear or is `ConnectionLost`, troubleshoot its
IAM role, SSM Agent, and outbound network access before running Ansible.

### 11.2 Test one direct Session Manager session

Use the actual Tomcat instance ID:

``` bash
aws ssm start-session \
  --target i-059d0709f7cfe3f50 #--target i-REPLACE_WITH_TOMCAT_INSTANCE_ID \
  --region us-east-1
```

Exit the session when finished:

``` bash
exit
```

### 11.3 Create an Ansible ping playbook

Create `playbooks/connectivity-test.yml`:

``` yaml
---
- name: Test Ansible connectivity through AWS SSM
  hosts: all
  gather_facts: false

  tasks:
    - name: Verify Ansible can execute a command
      ansible.builtin.raw: "echo SSM_CONNECTION_OK"

    - name: Display hostname
      ansible.builtin.raw: "hostname"
```

Run:

``` bash
ansible-playbook -i aws_ec2.yml playbooks/connectivity-test.yml
```

The `raw` module is useful as an initial transport test because it does
not require Python on the managed host. It does not behave exactly like
the normal Ansible `ping` module, which requires Python.

After verifying Python is available on the instances, test the normal
module:

``` bash
ansible all -i aws_ec2.yml -m ansible.builtin.ping
```

Expected result:

``` text
i-xxxxxxxxxxxxxxxxx | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

If the normal ping module fails because Python is missing, install
Python 3 using a `raw` task first, then retry.

------------------------------------------------------------------------

## 12. Run a first Ansible playbook

This is a small example to verify package management on Ubuntu. It
updates the APT cache and installs a basic utility.

Create `playbooks/common.yml`:

``` yaml
---
- name: Prepare Ubuntu EC2 instances
  hosts: all
  become: true
  gather_facts: false

  tasks:
    - name: Ensure Python 3 is installed
      ansible.builtin.raw: |
        if ! command -v python3 >/dev/null 2>&1; then
          apt-get update
          apt-get install -y python3
        fi

    - name: Gather facts
      ansible.builtin.setup:

    - name: Update APT package cache
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Install common administration utilities
      ansible.builtin.apt:
        name:
          - curl
          - wget
          - unzip
          - jq
          - net-tools
        state: present
```

Run a syntax check:

``` bash
ansible-playbook -i aws_ec2.yml --syntax-check playbooks/common.yml
```

Preview the target hosts:

``` bash
ansible-playbook -i aws_ec2.yml --list-hosts playbooks/common.yml
```

Run the playbook:

``` bash
ansible-playbook -i aws_ec2.yml playbooks/common.yml
```

For the first run, you may choose to limit execution to one instance:

``` bash
ansible-playbook playbooks/common.yml \
  --limit i-REPLACE_WITH_TOMCAT_INSTANCE_ID
```

------------------------------------------------------------------------

## 13. Organize the four server roles

Once SSM connectivity is proven, configure each server with a dedicated
Ansible role.

### 13.1 Target groups

The dynamic inventory groups are:

  Inventory group           Intended role
  ------------------------- -----------------
  `name_ec2_tomcat_01`      Tomcat and Java
  `name_ec2_mariadb_01`     MariaDB
  `name_ec2_rabbitmq_01`    RabbitMQ
  `name_ec2_memcached_01`   Memcached

Check the actual groups with:

``` bash
ansible-inventory --graph
```

### 13.2 Tomcat playbook

Create `playbooks/tomcat.yml`:

``` yaml
---
- name: Configure Tomcat application server
  hosts: name_ec2_tomcat_01
  become: true
  roles:
    - tomcat
```

### 13.3 MariaDB playbook

Create `playbooks/mariadb.yml`:

``` yaml
---
- name: Configure MariaDB database server
  hosts: name_ec2_mariadb_01
  become: true
  roles:
    - mariadb
```

### 13.4 RabbitMQ playbook

Create `playbooks/rabbitmq.yml`:

``` yaml
---
- name: Configure RabbitMQ message broker
  hosts: name_ec2_rabbitmq_01
  become: true
  roles:
    - rabbitmq
```

### 13.5 Memcached playbook

Create `playbooks/memcached.yml`:

``` yaml
---
- name: Configure Memcached cache server
  hosts: name_ec2_memcached_01
  become: true
  roles:
    - memcached
```

These playbooks establish the role boundaries; the role task files still
need to be implemented and tested.

### 13.6 Run each playbook

``` bash
ansible-playbook playbooks/tomcat.yml
ansible-playbook playbooks/mariadb.yml
ansible-playbook playbooks/rabbitmq.yml
ansible-playbook playbooks/memcached.yml
```

Run a specific playbook against one instance by using `--limit` with its
instance ID.

### 13.7 Application traffic and security groups

The intended application flow is:

  ------------------------------------------------------------------------
  Source           Destination                       Port Purpose
  ---------------- ---------------- --------------------- ----------------
  ALB security     Tomcat security               TCP 8080 HTTP traffic to
  group            group                                  Tomcat

  Tomcat security  MariaDB security              TCP 3306 Database
  group            group                                  connection

  Tomcat security  RabbitMQ                      TCP 5672 Messaging
  group            security group                         

  Tomcat security  Memcached                    TCP 11211 Caching
  group            security group                         
  ------------------------------------------------------------------------

Do not expose MariaDB, RabbitMQ, or Memcached to `0.0.0.0/0`. Their
inbound rules should reference the Tomcat/application security group.

The ALB target group must use the Tomcat listener port `8080` once
Tomcat is configured. The target group health-check path must match an
endpoint that actually returns a successful status from the deployed
application.

------------------------------------------------------------------------

## 14. Troubleshooting

### 14.1 `SSM Agent is not online`

Check:

-   EC2 instance is running.
-   IAM instance profile is attached.
-   The role includes `AmazonSSMManagedInstanceCore`.
-   SSM Agent is installed and running.
-   Instance has outbound HTTPS connectivity to the required Systems
    Manager endpoints.
-   DNS resolution and route table are correct.

On Ubuntu, if you can access the instance through an approved recovery
method, inspect:

``` bash
sudo systemctl status amazon-ssm-agent
sudo journalctl -u amazon-ssm-agent --no-pager -n 100
```

Some Ubuntu images may not have the agent installed or enabled. Verify
the actual AMI rather than assuming it is present.

### 14.2 `TargetNotConnected`

Usually means the instance is not currently connected to Systems
Manager. Check SSM Agent, IAM role, and network connectivity.

### 14.3 `AccessDeniedException`

Check the operator's SSO permission set. The EC2 instance role and the
operator's IAM identity have different responsibilities.

Also verify that the operator can access the configured S3 bucket.

### 14.4 `SessionManagerPlugin is not found`

Install the Session Manager plugin on the Ubuntu controller and confirm
that it is in the executable search path:

``` bash
command -v session-manager-plugin
session-manager-plugin
```

### 14.5 Dynamic inventory returns no hosts

Check:

``` bash
aws sso login --profile terraform-lab

aws ec2 describe-instances \
  --profile terraform-lab \
  --region us-east-1
```

Then verify:

-   The four instances are running.
-   The `Name` tags match the inventory filter exactly.
-   The inventory plugin collection is installed.
-   The correct region and profile are selected.
-   The SSO identity has EC2 describe permissions.

### 14.6 S3 transfer errors

Check:

-   Bucket name is correct.
-   Bucket is in the intended region.
-   Operator identity has the necessary S3 permissions.
-   Bucket policy does not deny the required operations.
-   Workstation and EC2 network paths can reach S3.
-   The bucket has not been deleted or had its objects expired during an
    active run.

### 14.7 Ansible `ping` fails but SSM session works

A working SSM session proves the basic session path, but does not prove
that Ansible's S3 transfer and Python execution requirements are
satisfied.

Check the S3 configuration and permissions, plugin version, Python
availability, and Ansible verbose output:

``` bash
ansible all -i aws_ec2.yml -m ansible.builtin.ping -vvvv
```

Avoid posting verbose logs publicly without reviewing them for account
identifiers, internal hostnames, and other sensitive information.

------------------------------------------------------------------------

## 15. Security recommendations

1.  Keep all four EC2 instances in private subnets without public IP
    addresses.
2.  Do not open inbound TCP/22 to the internet.
3.  Use SSM Session Manager for administration.
4.  Attach `AmazonSSMManagedInstanceCore` to the EC2 instance role.
5.  Give the operator's SSO identity only the permissions needed for EC2
    discovery, SSM sessions, and S3 transfers.
6.  Block all public access to the S3 transfer bucket.
7.  Enable S3 default encryption.
8.  Do not store AWS credentials, passwords, database credentials, or
    private keys in Git.
9.  Use Ansible Vault or a dedicated secrets manager for application
    secrets.
10. Keep application security groups restricted to the required source
    security groups.
11. Consider S3 and Systems Manager VPC endpoints in a production design
    to reduce dependence on NAT for AWS service traffic.
12. Review Session Manager logging and retention requirements before
    using this design in production.

------------------------------------------------------------------------

## 16. Cost considerations

### S3

Creating an empty S3 bucket does not itself incur a creation fee.
Charges may apply for storage, requests, retrieval, and data transfer.
Free Tier benefits depend on the account's enrollment date, eligibility,
and remaining credits or allowances.

### NAT Gateway

NAT Gateway hourly and data-processing charges can be more significant
than the small S3 transfer bucket. Check current regional pricing and
remove lab resources when they are no longer required.

### Systems Manager

Check the current AWS Systems Manager pricing page for any chargeable
features you enable. Do not assume that every Systems Manager capability
is free in every usage pattern or Region.

### EC2

Four running EC2 instances, their EBS volumes, the ALB, NAT Gateway, and
data transfer can all contribute to the workshop bill. Stop or destroy
resources when the lab is not in use, taking care not to delete data you
need.

Official pricing: - https://aws.amazon.com/s3/pricing/ -
https://aws.amazon.com/vpc/pricing/ -
https://aws.amazon.com/systems-manager/pricing/ -
https://aws.amazon.com/ec2/pricing/

------------------------------------------------------------------------

## 17. Operational checklist

### AWS infrastructure

-   [ ] Four Ubuntu 22.04 EC2 instances are running.
-   [ ] All four instances are in the private subnet.
-   [ ] No public IP addresses are assigned to the four instances.
-   [ ] The SSM IAM instance profile is attached to all four instances.
-   [ ] The instance role includes `AmazonSSMManagedInstanceCore`.
-   [ ] The private subnet has a default route to the NAT Gateway.
-   [ ] The required security-group relationships are in place.

### Ansible controller

-   [ ] AWS CLI v2 installed.
-   [ ] SSO profile `terraform-lab` works.
-   [ ] Ansible installed.
-   [ ] `boto3` and `botocore` installed.
-   [ ] `amazon.aws` collection installed.
-   [ ] Session Manager plugin installed.
-   [ ] S3 transfer bucket created, encrypted, and private.
-   [ ] Operator SSO permissions verified.

### Connectivity and automation

-   [ ] All four instances show `Online` in Systems Manager.
-   [ ] Direct `aws ssm start-session` works for Tomcat.
-   [ ] Dynamic inventory discovers all four instances.
-   [ ] Ansible SSM connection works.
-   [ ] Ansible ping succeeds after Python is available.
-   [ ] Common configuration playbook runs successfully.
-   [ ] Each application role is implemented and tested separately.

------------------------------------------------------------------------

## 18. Official documentation

-   [Ansible AWS SSM connection
    plugin](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ssm_connection.html)
-   [Ansible AWS EC2 dynamic
    inventory](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
-   [Amazon AWS
    collection](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/)
-   [AWS Systems Manager Session
    Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
-   [Install Session Manager plugin on
    Linux](https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-linux.html)
-   [Systems Manager
    prerequisites](https://docs.aws.amazon.com/systems-manager/latest/userguide/prereqs.html)
-   [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/)

------------------------------------------------------------------------

## Final architecture decision

For this workshop, use **Ansible + AWS Systems Manager Session Manager**
as the administration and configuration-management path.

This preserves the private-subnet design:

-   No public IPs on application or backend EC2 instances.
-   No inbound SSH rule required.
-   ALB reaches Tomcat over private VPC networking.
-   Private instances use NAT for outbound internet access.
-   Ansible manages the four servers through SSM.

Start by validating SSM registration and the Ansible connectivity test.
Do not begin the application installation roles until the connectivity
test succeeds.
