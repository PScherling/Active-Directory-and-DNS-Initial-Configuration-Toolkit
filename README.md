# Active Directory / DNS Server Initial Configuration

## Overview
This repository contains a **fully automated PowerShell-based setup framework** for deploying and configuring a complete **Active Directory Domain Controller** with integrated **DNS Server** and post-deployment automation scripts.  
Designed for reliability, repeatability, and logging, this toolkit enables system administrators to bootstrap an entire Windows Server AD environment from zero, including OU structure, GPOs, users, and groups.

---

## Key Features
- Automated Active Directory and DNS configuration
- Domain setup and post-installation routines
- Automated creation of Organizational Units (OU) and GPO linking
- Bulk import/export of AD users and groups
- Automated OU-to-GPO linking and policy deployment
- Extendable modular script design
- Centralized logging with detailed status output
- Supports multi-DC environments (including Add-DC automation)

---

## System Requirements

| Requirement | Minimum |
|--------------|----------|
| **OS** | Windows Server 2019 / 2022 / 2025 |
| **PowerShell** | Version 5.1 or later |
| **Privileges** | Must be executed as Administrator |
| **Network** | Static IP configuration recommended |
| **Modules** | ActiveDirectory, DnsServer |

---

## Domain Configuration

| Parameter | Value |
|------------|--------|
| **Domain Name** | `domain.at` |
| **NetBIOS Name** | `DOMAIN` |
| **Root OU Name** | `CompanyRoot` |
| **DNS Forwarders** | `8.8.8.8`, `1.1.1.1` |

---

## Folder & Script Structure

### 0_DNS_AD_Initial_Setup
| Script | Description |
|---------|--------------|
| **1_ad-dns-server-configuration_final.ps1** | Installs and configures DNS Server roles and forwarders. |
| **2_ad-setup_final.ps1** | Promotes the server to a new domain controller and creates the `domain.at` forest. |
| **3_ad-post-setup-tasks_final.ps1** | Performs domain post-setup configurations such as DNS verification and replication settings. |
| **4_ad-setup_add-dc_final.ps1** | Adds an additional Domain Controller to an existing domain. |

---

### 1_GroupPolicies
| Script | Description |
|---------|--------------|
| **1_AddAndImport_GPOSet.ps1** | Imports pre-defined GPO backups and links them to their respective OUs. |
| **2_CreateCentralPolicyStore.ps1** | Creates a central policy store in `SYSVOL` for unified GPO management. |

---

### 2_OU-Template_Import
| Script | Description |
|---------|--------------|
| **1_ad-ou-std-creation_final.ps1** | Creates a standardized OU hierarchy under `CompanyRoot` to maintain a clean and structured AD layout. |

---

### 3_AD_Gruppen_Import
| Script | Description |
|---------|--------------|
| **1_group-import_final.ps1** | Bulk-imports Active Directory groups from a predefined CSV file. |

---

### 4_AD_User_Import
| Script | Description |
|---------|--------------|
| **1_user-import_final.ps1** | Bulk-imports users into Active Directory with properties such as department, email, and group membership. |

---

### 5_AD_AddUserToGroup
| Script | Description |
|---------|--------------|
| **1_ad-adduserstogroups_final.ps1** | Automates adding users to security or distribution groups based on input mappings. |

---

### 6_AD_OU-GPO-Link_Import
| Script | Description |
|---------|--------------|
| **1_ou-gpo-link-import_final.ps1** | Links existing Group Policies to Organizational Units using CSV mapping for consistent deployment. |

---

### 7_AD_User-Export-Import
| Script | Description |
|---------|--------------|
| **AD-bulk-user-export.ps1** | Exports existing AD users to CSV for backup or replication. |
| **AD-bulk-user-import.ps1** | Re-imports users from CSV into the domain, preserving key attributes. |

---

## Execution Order

1 **DNS and Domain Setup**
```powershell
. 1_ad-dns-server-configuration_final.ps1
. 2_ad-setup_final.ps1
. 3_ad-post-setup-tasks_final.ps1
```

2 **OU and GPO Configuration**
```powershell
. 1_AddAndImport_GPOSet.ps1
. 2_CreateCentralPolicyStore.ps1
. 1_ad-ou-std-creation_final.ps1
```

3 **Group and User Import**
```powershell
. 1_group-import_final.ps1
. 1_user-import_final.ps1
. 1_ad-adduserstogroups_final.ps1
```

4 **Linking and Export**
```powershell
. 1_ou-gpo-link-import_final.ps1
. 1_AD-bulk-user-export.ps1
. 1_AD-bulk-user-import.ps1
```

---

## Logging

All scripts include a built-in logging mechanism that records:
- Execution time and hostname
- Script actions and PowerShell output
- Error details and exception traces  

Default log directory:
```
C:\_it\Logs\
```
or on remote log share:
```
\\<MDT-Server>\Logs$\Custom\
```

---

## Notes & Best Practices
- Always execute PowerShell with **Administrator privileges**
- Verify **network and DNS connectivity** before promotion
- Customize CSVs before importing groups or users
- The scripts are **idempotent** where possible (safe to re-run)
- Ensure **secure storage** of credential and product key data
- Use a **staging environment** before running in production

---

## Author

**Author:** Patrick Scherling  
**Solution:** Active Directory / DNS Server Initial Configuration  
**Contact:** @Patrick Scherling  

---

> âš¡ *â€œAutomate. Standardize. Simplify.â€*  
> This repository is part of Patrick Scherlingâ€™s IT automation toolset for efficient Windows infrastructure deployment.
