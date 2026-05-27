# ☁️ Foundational Cloud Provisioning

> **Assignment 2** — Provision and manage cloud infrastructure using declarative Infrastructure-as-Code (IaC) on AWS with Terraform.

---

## 📋 Overview

This project provisions a complete, production-style network environment and compute server on **AWS (ap-south-1 / Mumbai)** entirely through Terraform code — no clicking in the AWS Console required.

The infrastructure includes a custom VPC, a public subnet with internet routing, a security group, and an EC2 instance running the latest Ubuntu 22.04 LTS — all tagged and organized consistently.

---

## 🏗️ Architecture

```
                        Internet
                           │
                    ┌──────▼──────┐
                    │   Internet  │
                    │   Gateway   │
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │       VPC (dev-vpc)     │
              │      10.0.0.0/16        │
              │                         │
              │  ┌───────────────────┐  │
              │  │  Public Subnet    │  │
              │  │  10.0.1.0/24      │  │
              │  │  ap-south-1a      │  │
              │  │                   │  │
              │  │  ┌─────────────┐  │  │
              │  │  │  EC2 t2.micro│  │  │
              │  │  │  Ubuntu 22.04│  │  │
              │  │  │  Port 22,80  │  │  │
              │  │  └─────────────┘  │  │
              │  └───────────────────┘  │
              └─────────────────────────┘
```

---

## 📦 Resources Provisioned

| Resource | Name | Description |
|---|---|---|
| `aws_vpc` | `dev-vpc` | Custom VPC with DNS enabled (`10.0.0.0/16`) |
| `aws_subnet` | `dev-public-subnet` | Public subnet in `ap-south-1a` (`10.0.1.0/24`) |
| `aws_internet_gateway` | `dev-igw` | Internet Gateway attached to the VPC |
| `aws_route_table` | `dev-public-rt` | Route table with `0.0.0.0/0 → IGW` |
| `aws_route_table_association` | — | Links route table to the public subnet |
| `aws_security_group` | `dev-server-sg` | Allows SSH (22) and HTTP (80) inbound |
| `data.aws_ami` | `ubuntu_22_04` | **Dynamically fetched** latest Ubuntu 22.04 LTS AMI |
| `aws_instance` | `dev-server` | `t2.micro` EC2 instance on the public subnet |

---

## 🔑 Key Design Decisions

### ✅ Dynamic AMI Lookup (No Hardcoding)
Instead of hardcoding an AMI ID (which is region-specific and goes stale), this project uses a `data "aws_ami"` block to always fetch the **latest canonical Ubuntu 22.04 LTS image** at plan time:

```hcl
data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

### ✅ Genuinely Public Subnet
The subnet has `map_public_ip_on_launch = true` so EC2 instances automatically receive a public IP — no Elastic IPs needed. It's backed by an Internet Gateway and an explicit Route Table with a `0.0.0.0/0` route.

### ✅ Consistent Tagging
Every resource carries a `Project = "Cloud-Provisioning-Task"` tag for cost tracking and resource filtering in the AWS Console.

### ✅ Mumbai Region (ap-south-1)
Deliberately chosen over default US regions for lower latency from India — a realistic production choice for a local developer.

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| Terraform | `>= 1.3.0` | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | `v2` | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| AWS Account | — | [Free Tier](https://aws.amazon.com/free/) |

### 1. Configure AWS Credentials

```bash
aws configure
```
```
AWS Access Key ID     : YOUR_ACCESS_KEY
AWS Secret Access Key : YOUR_SECRET_KEY
Default region name   : ap-south-1
Default output format : json
```

### 2. Clone the Repository

```bash
git clone https://github.com/ramkaranpatel4661/Foundational-Cloud-Provisioning.git
cd Foundational-Cloud-Provisioning
```

### 3. (Optional) Add your Key Pair

If you want SSH access to the instance, uncomment this line in `main.tf`:

```hcl
# key_name = "your-key-pair-name"
```

---

## ⚡ Terraform Lifecycle

### Initialize — Download AWS Provider

```bash
terraform init
```

<details>
<summary>Expected output</summary>

```
Initializing provider plugins...
- Installing hashicorp/aws v5.x.x...
- Installed hashicorp/aws v5.x.x (signed by HashiCorp)

Terraform has been successfully initialized!
```
</details>

---

### Plan — Preview Infrastructure

```bash
terraform plan
```

This shows exactly what Terraform will create — **no changes are made to AWS at this step.**

<details>
<summary>Expected output (abbreviated)</summary>

```
Terraform will perform the following actions:

  # aws_instance.dev_server will be created
  # aws_internet_gateway.dev_igw will be created
  # aws_route_table.dev_public_rt will be created
  # aws_route_table_association.dev_public_rta will be created
  # aws_security_group.dev_sg will be created
  # aws_subnet.dev_public_subnet will be created
  # aws_vpc.dev_vpc will be created

Plan: 7 to add, 0 to change, 0 to destroy.
```
</details>

---

### Apply — Provision on AWS

```bash
terraform apply
```

Type `yes` when prompted. After ~2 minutes:

```
Outputs:

server_public_ip = "13.233.xx.xx"
```

---

### Destroy — Tear Down Everything

```bash
terraform destroy
```

Removes **all** resources created by this configuration. Always run this after the assignment to avoid AWS charges.

---

## 📁 Project Structure

```
Foundational-Cloud-Provisioning/
├── main.tf                  # All infrastructure configuration
├── .terraform.lock.hcl      # Provider version lock file
├── .gitignore               # Excludes state files and provider binaries
└── README.md                # This file
```

---

## 🔒 Security Notes

- SSH (`0.0.0.0/0`) is open for assignment requirements — in production, restrict to a specific IP or VPN CIDR.
- AWS credentials are **never** stored in code. Always use `aws configure` or environment variables.
- `.tfstate` files are excluded from git — they can contain sensitive resource metadata.

---

## 📤 Outputs

| Output | Description |
|---|---|
| `server_public_ip` | Public IPv4 address of the EC2 instance |

After `terraform apply`, SSH into the server:

```bash
ssh -i your-key.pem ubuntu@<server_public_ip>
```

---

## 👤 Author

**Ramkaran Patel**  
Assignment 2 — Foundational Cloud Provisioning  
Region: `ap-south-1` (Mumbai, India)

---

<div align="center">
  <sub>Built with ❤️ using Terraform + AWS</sub>
</div>
