# AWS Multi-Tier Application Infrastructure Automation

> **Project focus:** Infrastructure as Code (Terraform) + Configuration
> Management (Ansible)\
> **Source:** Senior Academy project requirements

## 1. Project Overview

Build a complete AWS environment for a multi-tier web application by
separating infrastructure provisioning from operating-system
configuration and application deployment.

-   **Terraform** defines and provisions AWS networking, security,
    compute, and load-balancing resources.
-   **Ansible** configures all four Linux instances, installs and
    manages their services, and deploys the application.
-   The application integrates with **MariaDB**, **RabbitMQ**, and
    **Memcached** over private network connections.
-   External users access the application through an **AWS Application
    Load Balancer (ALB)**.

## 2. Infrastructure as Code Layer --- Terraform

**Toolchain:** HashiCorp Terraform using HCL.

### 2.1 Network Infrastructure

Create and configure the following network resources:

  -----------------------------------------------------------------------
  Resource                            Required configuration
  ----------------------------------- -----------------------------------
  VPC                                 CIDR `10.0.0.0/16`

  Public subnet                       CIDR `10.0.1.0/24`

  Private subnet                      CIDR `10.0.2.0/24`

  Internet Gateway                    Provision and attach to the VPC

  Public route table                  Configure appropriate public
                                      routing

  Private route table                 Configure appropriate private
                                      routing

  NAT Gateway or approved alternative Provide private instances with
                                      outbound internet access when
                                      needed for software installation
                                      and updates
  -----------------------------------------------------------------------

Configure appropriate network isolation between public-facing and
internal application components.

### 2.2 EC2 Instance Provisioning

Terraform must provision **four Linux EC2 instances**, each dedicated to
a service.

#### Instance 1 --- Application Server

-   Host the web application.
-   Install and configure Nginx through Ansible.
-   Run the application and expose its required internal application
    port.
-   Configure Nginx as a reverse proxy.
-   Place the instance in the **public subnet**.

#### Instance 2 --- MariaDB Server

-   Host the MariaDB relational database.
-   Store and manage application data.
-   Accept database connections only from authorized application
    instances.
-   Place the instance in the **private subnet**.

#### Instance 3 --- RabbitMQ Server

-   Host the RabbitMQ message broker.
-   Enable asynchronous communication between application components.
-   Restrict message broker access to authorized application instances.
-   Place the instance in the **private subnet**.

#### Instance 4 --- Memcached Server

-   Host the Memcached caching service.
-   Provide in-memory caching to improve application performance.
-   Restrict cache access to authorized application instances.
-   Place the instance in the **private subnet**.

### 2.3 Security Groups

Terraform must create dedicated Security Groups for each EC2 instance.

  -----------------------------------------------------------------------
  Security Group                      Required inbound access
  ----------------------------------- -----------------------------------
  Application                         HTTP TCP `80` from the Application
                                      Load Balancer; allow
                                      application-related internal
                                      traffic where required; restrict
                                      administrative access

  MariaDB                             TCP `3306` only from the
                                      Application Server Security Group

  RabbitMQ                            TCP `5672` only from the
                                      Application Server Security Group;
                                      restrict management-interface
                                      access

  Memcached                           TCP `11211` only from the
                                      Application Server Security Group
  -----------------------------------------------------------------------

Apply least-privilege access rules. Do not expose backend services
directly to the public internet.

### 2.4 Load Balancing

Provision an AWS Application Load Balancer with the following
configuration:

-   Create an internet-facing ALB.
-   Configure an HTTP listener on port `80`.
-   Create a Target Group for the Application Server.
-   Register the Application EC2 instance with the Target Group.
-   Configure health checks to monitor application availability.
-   Allow external users to access the application through the ALB DNS
    name.

**Scaling consideration:** The initial deployment uses one Application
Server. The architecture must support future horizontal scaling by
adding more application instances.

## 3. Configuration Management and Deployment Layer --- Ansible

**Toolchain:** Ansible playbooks (`.yml`) to automate operating-system
configuration, software installation, application deployment, and
service management across all four EC2 instances.

### 3.1 Inventory Management

-   Configure an Ansible inventory containing all four EC2 instances.
-   Organize hosts into the following groups:
    -   `app`
    -   `mariadb`
    -   `rabbitmq`
    -   `memcached`
-   Support dynamic inventory using AWS EC2 instance metadata and tags.
-   Ensure Ansible can securely connect to target instances without
    requiring manual configuration.

### 3.2 Operating System Configuration

Ansible must perform the following tasks across all instances:

-   Update system package repositories.
-   Install required system packages.
-   Apply available security updates.
-   Configure required Linux services.
-   Enable required services to start automatically after reboot.
-   Apply basic operating-system security hardening.

### 3.3 Application Server Deployment

Ansible must:

-   Install Nginx.
-   Install the required application runtime and dependencies.
-   Deploy the application source code.
-   Configure application environment variables.
-   Configure Nginx as a reverse proxy.
-   Configure the application to communicate with MariaDB, RabbitMQ, and
    Memcached.
-   Enable and start the application service.
-   Enable and start Nginx.
-   Verify that the application is accessible through HTTP.

### 3.4 MariaDB Deployment

Ansible must:

-   Install MariaDB Server.
-   Configure MariaDB to listen on the required private network
    interface.
-   Create the application database.
-   Create a dedicated database user.
-   Assign appropriate database privileges.
-   Configure secure database authentication.
-   Enable and start the MariaDB service.
-   Verify database connectivity from the Application Server.

### 3.5 RabbitMQ Deployment

Ansible must:

-   Install RabbitMQ Server and required dependencies.
-   Configure the RabbitMQ service.
-   Create an application-specific RabbitMQ user.
-   Create the required Virtual Host.
-   Assign appropriate permissions.
-   Configure RabbitMQ to accept authorized connections.
-   Enable and start the RabbitMQ service.
-   Verify connectivity from the Application Server.

### 3.6 Memcached Deployment

Ansible must:

-   Install Memcached.
-   Configure Memcached to listen only on the private network interface.
-   Configure the required memory allocation.
-   Configure the service to use TCP port `11211`.
-   Enable and start the Memcached service.
-   Verify cache connectivity from the Application Server.

### 3.7 Ansible Roles and Playbook Organization

Use a modular Ansible structure with dedicated roles:

  Role          Responsibility
  ------------- --------------------------------------------------
  `common`      Operating-system updates and basic configuration
  `app`         Application and Nginx deployment
  `mariadb`     Database installation and configuration
  `rabbitmq`    Message broker installation and configuration
  `memcached`   Cache installation and configuration

A main Ansible playbook must orchestrate deployment of all services.

## 4. Application Architecture and Service Communication

The deployed application must follow a multi-tier architecture.

### 4.1 External Application Access

1.  End users access the application through the public DNS name of the
    ALB.
2.  The ALB forwards incoming HTTP requests to the Application Server.
3.  Nginx receives requests and forwards them to the application
    process.

### 4.2 Database Communication

-   The Application Server connects to MariaDB using the database
    instance's private IP address or private DNS name.
-   Database communication uses TCP port `3306`.
-   MariaDB must not be directly accessible from the public internet.

### 4.3 Message Broker Communication

-   The Application Server connects to RabbitMQ through the private
    network.
-   RabbitMQ uses TCP port `5672` for AMQP communication.
-   RabbitMQ must not be directly accessible from the public internet.

### 4.4 Caching Communication

-   The Application Server communicates with Memcached using TCP port
    `11211`.
-   Memcached provides temporary in-memory storage for application
    caching.
-   Memcached must not be directly accessible from the public internet.

### 4.5 Application Integration

The deployed application must demonstrate functional integration with
all three backend services:

-   **MariaDB:** Persistent data storage.
-   **RabbitMQ:** Asynchronous message processing.
-   **Memcached:** Application caching.

## 5. Infrastructure Provisioning and Deployment Workflow

The project must maintain a clear separation between infrastructure
provisioning and application configuration.

### Phase 1 --- Infrastructure Provisioning (Terraform)

1.  Write Terraform configuration files using HCL.
2.  Define the VPC, subnets, Internet Gateway, route tables, and
    Security Groups.
3.  Define the Application Load Balancer and Target Group.
4.  Define the four EC2 instances.
5.  Execute `terraform init`.
6.  Execute `terraform plan`.
7.  Execute `terraform apply`.
8.  Verify that all required AWS resources have been created
    successfully.

**Expected result:** A complete AWS infrastructure containing four
running EC2 instances and the required networking components.

### Phase 2 --- Configuration and Deployment (Ansible)

1.  Obtain the provisioned EC2 instance information.
2.  Generate or update the Ansible inventory.
3.  Execute the main Ansible playbook.
4.  Apply operating-system updates and basic security configuration.
5.  Install and configure MariaDB.
6.  Install and configure RabbitMQ.
7.  Install and configure Memcached.
8.  Deploy the application and configure Nginx.
9.  Enable and start all required services.
10. Validate application connectivity to all backend services.

**Expected result:** All four EC2 instances are configured
automatically, with the application and its dependencies successfully
deployed.

## 6. Acceptance Criteria and Validation

### 6.1 Automated Infrastructure Provisioning

Running `terraform apply` must successfully provision:

-   [ ] One custom VPC.
-   [ ] One public subnet.
-   [ ] One private subnet.
-   [ ] One Internet Gateway.
-   [ ] Required route tables and routing configurations.
-   [ ] Dedicated Security Groups.
-   [ ] Four Linux EC2 instances.
-   [ ] One Application Load Balancer.
-   [ ] One ALB Target Group.

**Acceptance criteria:** All required AWS resources are created
successfully without manual configuration through the AWS Console.

### 6.2 Automated Service Deployment

Running the main Ansible playbook must:

-   [ ] Configure all four EC2 instances.
-   [ ] Install and configure Nginx and the application.
-   [ ] Install and configure MariaDB.
-   [ ] Install and configure RabbitMQ.
-   [ ] Install and configure Memcached.
-   [ ] Enable and start all required services.

**Acceptance criteria:** All services are running successfully without
manual software installation or configuration.

### 6.3 Application Accessibility

-   [ ] Access the application through the ALB public DNS name.
-   [ ] Verify that HTTP requests reach the Application Server.
-   [ ] Verify that Nginx successfully forwards requests to the
    application.

**Acceptance criteria:** The application interface is successfully
displayed in a standard web browser.

### 6.4 Backend Service Connectivity

**MariaDB**

-   [ ] The application successfully connects to MariaDB.
-   [ ] Database read and write operations execute successfully.

**RabbitMQ**

-   [ ] The application successfully connects to RabbitMQ.
-   [ ] A test message can be published and consumed.

**Memcached**

-   [ ] The application successfully connects to Memcached.
-   [ ] Cache values can be stored and retrieved.

**Acceptance criteria:** All three backend services communicate
successfully with the application through private network connections.

### 6.5 Security Validation

-   [ ] MariaDB is accessible only from authorized application
    instances.
-   [ ] RabbitMQ is accessible only from authorized application
    instances.
-   [ ] Memcached is accessible only from authorized application
    instances.
-   [ ] Backend instances do not have public IP addresses.
-   [ ] Security Groups enforce the required access restrictions.

**Acceptance criteria:** Internal services are isolated from direct
public internet access.

### 6.6 Idempotency and Repeatability

-   [ ] Re-running the Ansible playbook must not introduce unnecessary
    configuration changes.
-   [ ] Re-running `terraform plan` after successful provisioning must
    show no unexpected infrastructure changes.
-   [ ] Infrastructure and application configurations must be maintained
    through version-controlled code.

**Acceptance criteria:** The environment can be consistently reproduced
and managed using Terraform and Ansible.

## 7. Completion Checklist

Use this checklist to track the overall project:

-   [ ] Terraform AWS provider and authentication configured.
-   [ ] VPC and subnet resources provisioned.
-   [ ] Internet Gateway and route tables configured.
-   [ ] NAT Gateway or approved private-subnet egress alternative
    configured where required.
-   [ ] Security Groups created with restricted access.
-   [ ] Four EC2 instances provisioned in their designated subnets.
-   [ ] Application Load Balancer and Target Group configured.
-   [ ] Ansible inventory configured.
-   [ ] Common operating-system configuration applied.
-   [ ] MariaDB installed and configured.
-   [ ] RabbitMQ installed and configured.
-   [ ] Memcached installed and configured.
-   [ ] Application deployed.
-   [ ] Nginx configured as a reverse proxy.
-   [ ] Application accessible through the ALB DNS name.
-   [ ] MariaDB integration tested.
-   [ ] RabbitMQ integration tested.
-   [ ] Memcached integration tested.
-   [ ] Security and network isolation validated.
-   [ ] Terraform repeatability validated.
-   [ ] Ansible idempotency validated.
-   [ ] Project documentation completed.

## 8. Notes and Design Considerations

The requirements specify one public subnet and one private subnet, with
one application instance in the public subnet and three backend
instances in the private subnet. They also require an ALB and restrict
application HTTP access to traffic from the ALB.

The exact deployment design should ensure that:

-   The ALB is placed in public subnets in at least two Availability
    Zones, as required by AWS for a standard Application Load Balancer.
-   The application instance's Security Group allows HTTP only from the
    ALB Security Group.
-   The three backend instances have no public IP addresses.
-   Administrative access is restricted and should use a secure
    management path.
-   Application and backend instances communicate over private
    addresses.
-   Secrets such as database passwords and RabbitMQ credentials are not
    committed to Git.

These considerations should be addressed during implementation while
retaining the stated project requirements.
