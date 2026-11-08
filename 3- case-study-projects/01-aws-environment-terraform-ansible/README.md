# End-to-End AWS Environment Provisioning using Terraform and Ansible

## Project Overview

This project demonstrates the end-to-end provisioning and configuration of an enterprise-style AWS environment using **Terraform** and **Ansible**.

The objective is to build a secure, scalable, and automated AWS infrastructure following cloud infrastructure best practices.

Terraform is responsible for provisioning the AWS infrastructure, networking components, security groups, IAM roles, and EC2 instances, while Ansible handles operating system preparation and application stack configuration.

The project deploys a multi-tier Java web application environment with all backend services isolated inside private subnets and an Application Load Balancer providing public access to the application.

## Project Objectives

- Design and deploy a secure AWS network architecture.
- Automate AWS infrastructure provisioning using Terraform.
- Implement public and private subnet isolation.
- Deploy an Application Load Balancer across multiple Availability Zones.
- Provision four Ubuntu 22.04 EC2 instances.
- Implement secure outbound internet connectivity using a NAT Gateway.
- Configure AWS Systems Manager (SSM) for instance administration without SSH.
- Automate server configuration using Ansible.
- Deploy and configure a Java application environment.
- Apply infrastructure-as-code and configuration-management best practices.

## Architecture

### High-Level Architecture

The environment follows a multi-tier architecture with separate networking and application layers.

```text
                         Internet
                            |
                            |
                     Internet Gateway
                            |
                            |
                  Application Load Balancer
                       (Public Subnets)
                            |
                            |
                    Target Group : 8080
                            |
             +--------------+--------------+
             |              |              |
             |       Private Subnets       |
             |                             |
             |       Tomcat Server         |
             |       (Java Application)    |
             |              |              |
             |       +------+------+       |
             |       |      |      |       |
             |    MariaDB RabbitMQ Memcached|
             |                             |
             +-----------------------------+
                            |
                       NAT Gateway
                            |
                         Internet
```

### AWS Infrastructure Components

| Component | Description |
|---|---|
| VPC | Isolated AWS virtual network |
| Public Subnets | Host the internet-facing Application Load Balancer and NAT Gateway |
| Private Subnets | Host application and backend EC2 instances |
| Internet Gateway | Provides internet connectivity to public subnets |
| NAT Gateway | Provides outbound internet access to private instances |
| Route Tables | Control public and private network traffic |
| Application Load Balancer | Distributes incoming HTTP/HTTPS traffic to the application tier |
| Security Groups | Control communication between infrastructure components |
| IAM Role | Grants EC2 instances permissions to communicate with AWS Systems Manager |
| EC2 Instances | Host the application and backend services |
| AWS Systems Manager | Provides secure instance administration without SSH access |

### EC2 Instances

Four Ubuntu Server 22.04 LTS instances are deployed inside private subnets.

| Instance | Role | Service | Port |
|---|---|---|---|
| ec2-tomcat-01 | Application Server | Apache Tomcat 9 / Java 11 | 8080 |
| ec2-mariadb-01 | Database Server | MariaDB | 3306 |
| ec2-rabbitmq-01 | Message Broker | RabbitMQ | 5672 |
| ec2-memcached-01 | Caching Server | Memcached | 11211 |

All EC2 instances are deployed without public IP addresses.

The Tomcat server receives application traffic through the Application Load Balancer. Backend services are accessible only through their required private network connections.

## Network Architecture

The project uses a dedicated VPC with the following initial network design:

| Resource | CIDR |
|---|---|
| VPC | 10.0.0.0/16 |
| Public Subnet | 10.0.1.0/24 |
| Private Subnet | 10.0.2.0/24 |

The final subnet layout uses multiple Availability Zones to support the Application Load Balancer.

### Public Subnets

Public subnets are used for internet-facing infrastructure:

- Application Load Balancer.
- NAT Gateway.
- Internet Gateway connectivity.

### Private Subnets

Private subnets are used for application workloads:

- Tomcat application server.
- MariaDB database server.
- RabbitMQ message broker.
- Memcached caching server.

Private instances do not receive public IP addresses.

### Traffic Flow

**Inbound traffic:**

1. External clients access the application through the internet.
2. The Internet Gateway provides connectivity to the public subnets.
3. The Application Load Balancer receives incoming HTTP/HTTPS requests.
4. The ALB forwards requests to the Tomcat server on port 8080.
5. Tomcat communicates with MariaDB, RabbitMQ, and Memcached using private IP addresses.

**Outbound traffic:**

1. Private EC2 instances initiate outbound connections when required.
2. Traffic is routed through the NAT Gateway.
3. The NAT Gateway forwards traffic through the Internet Gateway.

## Technology Stack

| Technology | Purpose |
|---|---|
| AWS | Cloud infrastructure |
| Terraform | Infrastructure as Code |
| Ansible | Configuration Management |
| Ubuntu 22.04 LTS | Operating System |
| EC2 | Compute |
| VPC | Network isolation |
| Application Load Balancer | Application traffic distribution |
| NAT Gateway | Private subnet outbound connectivity |
| IAM | Identity and access management |
| AWS Systems Manager | Secure instance administration |
| Java 11 | Application runtime |
| Apache Tomcat 9 | Java application server |
| MariaDB | Relational database |
| RabbitMQ | Message broker |
| Memcached | In-memory caching |
| Git | Version control |
| WSL | Ansible execution environment |

## Repository Structure

```text
aws-environment-terraform-ansible/
│
├── README.md
│
├── terraform/
│   ├── providers.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── main.tf
│   ├── vpc.tf
│   ├── subnets.tf
│   ├── internet-gateway.tf
│   ├── nat-gateway.tf
│   ├── route-tables.tf
│   ├── security-groups.tf
│   ├── iam.tf
│   ├── ec2.tf
│   ├── alb.tf
│   └── outputs.tf
│
└── ansible/
    ├── ansible.cfg
    ├── aws_ec2.yml
    │
    ├── group_vars/
    │   └── all/
    │       ├── vars.yml
    │       └── vault.yml
    │
    ├── playbooks/
    │   ├── connectivity-test.yml
    │   ├── common.yml
    │   ├── mariadb.yml
    │   ├── rabbitmq.yml
    │   ├── memcached.yml
    │   └── tomcat.yml
    │
    └── roles/
        ├── common/
        ├── mariadb/
        ├── rabbitmq/
        ├── memcached/
        └── tomcat/
```

*Note: The structure represents the logical organization of the project; filenames can be adjusted to match the final repository.*

## Phase 1: AWS Authentication and Terraform Setup

Configure AWS authentication using AWS IAM Identity Center (SSO).

Configure the AWS CLI with the required profile and region.

Example:

```bash
aws configure sso
aws sso login --profile <profile-name>
```

Verify authentication:

```bash
aws sts get-caller-identity --profile <profile-name>
```

Initialize Terraform:

```bash
cd terraform

terraform init
```

Validate the configuration:

```bash
terraform fmt -recursive
terraform validate
terraform plan
```

Apply the infrastructure:

```bash
terraform apply
```

## Phase 2: Infrastructure Provisioning with Terraform

Terraform provisions the following infrastructure components:

1. AWS VPC.
2. Public and private subnets across Availability Zones.
3. Internet Gateway.
4. NAT Gateway and Elastic IP.
5. Public and private route tables.
6. Security groups.
7. IAM roles and instance profiles.
8. EC2 instances.
9. Application Load Balancer.
10. Target groups and listener configuration.

The infrastructure is designed to provide network isolation and controlled communication between application tiers.

## Phase 3: Secure Instance Administration using AWS SSM

AWS Systems Manager is used to manage EC2 instances without exposing SSH access.

The EC2 instances are configured with:

- An IAM instance role with the required Systems Manager permissions.
- Systems Manager Agent.
- Outbound connectivity to the required AWS Systems Manager endpoints through the NAT Gateway.
- No public IP addresses.
- No inbound SSH access.

This approach eliminates the need to distribute or manage SSH private keys for instance administration.

## Phase 4: Ansible Configuration Management

Ansible is used to automate the configuration of all four EC2 instances.

Ansible runs from WSL and uses AWS dynamic inventory to discover EC2 instances based on their AWS tags.

### Dynamic Inventory

The `aws_ec2.yml` inventory plugin dynamically discovers EC2 instances.

This avoids maintaining static IP addresses and allows Ansible to identify instances using their Name tags.

Example inventory groups:

```text
name_ec2_tomcat_01
name_ec2_mariadb_01
name_ec2_rabbitmq_01
name_ec2_memcached_01
```

### Configuration Phases

**1. Common Configuration**

Prepare all EC2 instances with common system configuration:

- Update operating system packages.
- Install required system utilities.
- Configure common system settings.
- Prepare the environment for application installation.

**2. MariaDB Configuration**

Configure the database server:

- Install MariaDB.
- Configure database network access.
- Create application databases.
- Create application database users.
- Configure database authentication and permissions.

**3. RabbitMQ Configuration**

Configure the message broker:

- Install RabbitMQ and its dependencies.
- Enable and start the RabbitMQ service.
- Configure application credentials.
- Prepare RabbitMQ for application communication.

**4. Memcached Configuration**

Configure the caching server:

- Install Memcached.
- Configure network binding.
- Configure the listening port.
- Enable and start the Memcached service.

**5. Tomcat Configuration**

Configure the Java application server:

- Install Java 11.
- Install Maven.
- Install Apache Tomcat 9.
- Configure application connectivity.
- Build and deploy the Java application.
- Start and validate the Tomcat service.

## Phase 5: Application Deployment

The application server hosts the Java web application using Apache Tomcat.

The application communicates with the backend services using their private IP addresses.

| Backend Service | Port |
|---|---|
| MariaDB | 3306 |
| RabbitMQ | 5672 |
| Memcached | 11211 |

The Application Load Balancer forwards application traffic to Tomcat on port 8080.

The backend services remain isolated from direct public access.

## Security Implementation

Security is an important part of this project.

The following security practices are implemented:

- Private EC2 instances without public IP addresses.
- No direct inbound SSH access.
- AWS Systems Manager for secure administration.
- IAM instance profiles for AWS service permissions.
- Security groups with restricted service-to-service communication.
- Private database, messaging, and caching tiers.
- Application Load Balancer as the public entry point.
- NAT Gateway for controlled outbound connectivity.
- Ansible Vault for protecting sensitive configuration variables.
- Terraform variables for reusable infrastructure configuration.
- Sensitive Terraform state and credentials excluded from Git.

## Validation and Testing

The environment is validated at both infrastructure and application levels.

### Terraform Validation

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
```

### AWS Infrastructure Validation

Verify:

- VPC and subnet configuration.
- Route table associations.
- Internet Gateway and NAT Gateway status.
- EC2 instance state.
- Security group rules.
- IAM instance profiles.
- ALB listener configuration.
- Target group health.

### Ansible Validation

Check dynamic inventory:

```bash
ansible-inventory -i aws_ec2.yml --graph
```

Test connectivity:

```bash
ansible-playbook -i aws_ec2.yml playbooks/connectivity-test.yml
```

Run configuration playbooks:

```bash
ansible-playbook -i aws_ec2.yml playbooks/common.yml

ansible-playbook -i aws_ec2.yml playbooks/mariadb.yml

ansible-playbook -i aws_ec2.yml playbooks/rabbitmq.yml

ansible-playbook -i aws_ec2.yml playbooks/memcached.yml

ansible-playbook -i aws_ec2.yml playbooks/tomcat.yml
```

### Application Validation

Verify:

- Tomcat service is running.
- Backend services are active.
- Application can communicate with MariaDB.
- Application can communicate with RabbitMQ.
- Application can communicate with Memcached.
- ALB target health checks are successful.
- Application is accessible through the ALB DNS endpoint.

## Infrastructure Management

Terraform is responsible for infrastructure lifecycle management.

To review infrastructure changes:

```bash
terraform plan
```

To apply updates:

```bash
terraform apply
```

To destroy the lab environment when it is no longer required:

```bash
terraform destroy
```

**Important:** Terraform state files, AWS credentials, SSH private keys, and Ansible Vault passwords must never be committed to the public repository.

## Lessons Learned

This project provides practical experience with:

- Designing AWS network architectures.
- Implementing infrastructure as code.
- Automating cloud resource provisioning.
- Working with AWS IAM and Identity Center.
- Configuring secure private EC2 environments.
- Understanding AWS ALB and NAT Gateway traffic flows.
- Managing EC2 instances using AWS Systems Manager.
- Implementing dynamic AWS inventory with Ansible.
- Automating Linux server configuration.
- Deploying multi-tier Java applications.
- Applying security and automation best practices.

## Future Improvements

Potential enhancements include:

- Implement HTTPS using AWS Certificate Manager.
- Configure Auto Scaling for the application tier.
- Deploy multiple Tomcat instances across Availability Zones.
- Introduce RDS for managed database services.
- Implement centralized logging and monitoring.
- Integrate CloudWatch alarms and dashboards.
- Implement CI/CD using GitHub Actions.
- Add Terraform remote state management using S3 and DynamoDB-based locking where supported by the chosen Terraform backend configuration.
- Implement infrastructure security scanning.
---

