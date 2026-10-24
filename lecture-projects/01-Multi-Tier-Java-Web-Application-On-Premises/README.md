# Project 01 — Building a Multi-Tier Java Web Application On-Premises

<p align="center">
  <strong>DevOps Workshop | Lecture Project 01</strong>
</p>

<p align="center">
  Linux · Vagrant · VirtualBox · Nginx · Tomcat · MySQL · RabbitMQ · Memcached · Maven · Git
</p>

---

## Project Overview

This is a comprehensive, hands-on project designed to simulate a real-world enterprise IT environment. It covers the end-to-end local deployment of a scalable, multi-tier Java web application, focusing on manual infrastructure provisioning, component integration, networking, and configuration management.

The environment is built using local virtual machines rather than cloud-managed services. This approach provides practical experience with traditional on-premises infrastructure and helps develop the troubleshooting skills required to operate complex application environments.

The project also establishes the architectural foundation for subsequent DevOps practices, including infrastructure automation, CI/CD pipelines, and cloud-native deployments on AWS.

## Objectives

- Design and deploy a multi-tier Java web application in a local virtualized environment.
- Provision and configure Linux virtual machines.
- Configure communication between application components and infrastructure tiers.
- Integrate web, application, database, caching, and messaging services.
- Troubleshoot networking, service availability, database connectivity, and application runtime issues.
- Understand the deployment lifecycle before introducing automation and cloud-native architectures.

## Prerequisites

Successful completion of this project requires:

- A comprehensive understanding of DevOps methodologies and cloud computing architectures, particularly AWS.
- Proficiency in Linux system administration.
- Familiarity with Bash scripting and command-line tools.
- Foundational knowledge of networking, IP addressing, ports, DNS, and connectivity troubleshooting.
- Basic familiarity with Java web applications and application deployment concepts.
- A working understanding of Git and version control.

### Local Environment Requirements

- Oracle VirtualBox installed on the host machine.
- Vagrant installed and configured.
- Sufficient CPU, memory, and disk space to run the required virtual machines.
- Internet connectivity for downloading Vagrant boxes, packages, and application dependencies.

Exact hardware requirements depend on the number of virtual machines and the resource allocation chosen during implementation.

## Technologies and Tools

| Technology | Purpose |
|---|---|
| Linux (CentOS / Ubuntu) | Operating system for the virtual machines |
| Vagrant | Automated provisioning and management of local virtual machines |
| Oracle VirtualBox | Virtualization provider |
| Nginx | Web server and potential reverse proxy |
| Apache Tomcat | Java application server |
| MySQL | Relational database |
| RabbitMQ | Message queuing and asynchronous communication |
| Memcached | In-memory caching |
| Maven | Java dependency management and build automation |
| Git | Source code version control |

## Architecture Overview

The target environment consists of multiple infrastructure and application components operating together in a local virtualized environment.

```text
                  Client / Browser
                         |
                         v
                  +--------------+
                  |    Nginx     |
                  |  Web Tier    |
                  +--------------+
                         |
                         v
                  +--------------+
                  | Apache       |
                  | Tomcat       |
                  | Application  |
                  +--------------+
                         |
              +----------+----------+
              |          |          |
              v          v          v
        +----------+ +---------+ +-----------+
        |  MySQL   | | Memcached| | RabbitMQ  |
        | Database | |  Cache   | | Messaging |
        +----------+ +---------+ +-----------+
```

**Note:** This diagram illustrates the logical application tiers. The actual virtual machine placement, network topology, ports, and communication paths will be documented after the environment is implemented and validated.

## Knowledge and Skills Gained

### 1. Multi-Tier Application Architecture

Understand how web servers, application servers, databases, caching systems, and message brokers work together to deliver an application.

### 2. Local Infrastructure Provisioning

Provision, network, and configure virtual machines using Vagrant and VirtualBox, building a reproducible local lab.

### 3. Service Integration

Integrate MySQL, Memcached, and RabbitMQ with the application environment and understand their distinct roles.

### 4. Networking and Troubleshooting

Investigate connectivity issues between tiers, identify service and port problems, and troubleshoot database integration and application runtime errors.

### 5. Linux Administration and Configuration

Configure Linux services, manage packages, inspect logs, verify service health, and maintain consistent system configurations.

### 6. Application Build and Deployment

Use Maven to manage application dependencies and build artifacts, and Git to track changes throughout the development and deployment lifecycle.

## Implementation Roadmap

The project will be implemented in stages:

1. **Environment preparation** — Install and validate Vagrant and VirtualBox.
2. **Virtual machine provisioning** — Define the required virtual machines, resources, and networking.
3. **Linux configuration** — Install the operating systems' required packages and configure system settings.
4. **Database deployment** — Install MySQL and validate application database connectivity.
5. **Application server deployment** — Install and configure Apache Tomcat.
6. **Web tier configuration** — Configure Nginx and connect it to the application tier.
7. **Caching and messaging** — Deploy Memcached and RabbitMQ and validate service connectivity.
8. **Application build and deployment** — Use Maven to build the Java application and deploy the resulting artifact.
9. **Integration testing** — Validate application access, service communication, and expected functionality.
10. **Troubleshooting and documentation** — Record issues, root causes, solutions, and lessons learned.

The sequence may be adjusted to match the workshop's actual implementation steps.

## Validation and Testing

The completed environment should be validated through practical tests, including:

- Confirming that all virtual machines boot successfully.
- Verifying that the required services are running.
- Checking network connectivity between the application tiers.
- Confirming that Nginx can reach the Tomcat application.
- Testing database connectivity and application functionality.
- Validating access to Memcached and RabbitMQ from the relevant components.
- Reviewing service logs and troubleshooting failures.
- Confirming that the deployed application behaves as expected.

Actual test commands, outputs, and results will be added during implementation.

## Troubleshooting

This section will record issues encountered during the project.

| Issue | Root Cause | Resolution |
|---|---|---|
| To be documented | To be investigated | To be documented |

Troubleshooting notes will cover relevant areas such as virtual machine networking, firewall rules, service configuration, application logs, database access, and dependency failures.

## Project Deliverables

Upon completion, this repository is intended to contain:

- Vagrant configuration and virtual machine definitions.
- Relevant infrastructure and service configuration files.
- Application deployment instructions.
- Scripts created during the implementation.
- Architecture diagrams and selected screenshots.
- Validation procedures and test results.
- Troubleshooting notes and lessons learned.

## Purpose and Learning Outcomes

The primary purpose of this project is to establish a robust understanding of traditional on-premises infrastructure and application deployment lifecycles.

By mastering local, manual multi-tier deployments, engineers develop the architectural knowledge and troubleshooting skills needed to automate infrastructure, implement reliable CI/CD pipelines, and execute secure migrations to AWS.

This project serves as the foundation for the subsequent automation, containerization, Kubernetes, and cloud projects in this workshop.

## Repository Status

**Status:** In progress

Implementation details, configuration files, test results, and screenshots will be added as the project progresses.

## References

- [Vagrant Documentation](https://developer.hashicorp.com/vagrant/docs)
- [Oracle VirtualBox Documentation](https://www.virtualbox.org/wiki/Documentation)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Apache Tomcat Documentation](https://tomcat.apache.org/)
- [MySQL Documentation](https://dev.mysql.com/doc/)
- [RabbitMQ Documentation](https://www.rabbitmq.com/docs)
- [Memcached Documentation](https://docs.memcached.org/)
- [Apache Maven Documentation](https://maven.apache.org/guides/)
- [Git Documentation](https://git-scm.com/doc/)

---

*Part of the DevOps Workshop — 25 Hands-On Projects.*