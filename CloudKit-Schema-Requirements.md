# CloudKit Schema Requirements for RHEIR Multi-Tenant Organization System

## Overview
All organization data (vendors, payment methods, team members, projects, receipts) must be stored in CloudKit custom zones for proper team collaboration and data sharing.

**IMPORTANT PROJECT PERMISSIONS UPDATE:**
All team members (members, contractors, viewers) now only see projects they are specifically assigned to. Only admins see all organization projects.

## Required Record Types

### 1. **OrganizationRoot** Record Type (REQUIRED FOR SHARING)
**Fields needed:**
- `organizationID`: STRING (Queryable, Sortable) - UUID of the organization
- `name`: STRING (Queryable, Searchable, Sortable) - Display name for the organization
- `createdAt`: DATE/TIME (Sortable) - When the zone was created
- `zoneVersion`: INT64 - Version for zone management
- `description`: STRING - Optional description of the organization

**Purpose:** 
This is the root record that gets shared to enable team collaboration. Each organization zone must have exactly one OrganizationRoot record that serves as the anchor for CloudKit sharing.

### 2. **Organization** Record Type
**Fields needed:**
- `id`: STRING (Queryable, Sortable) - UUID
- `name`: STRING (Queryable, Searchable, Sortable)
- `adminUserID`: STRING (Queryable) - CloudKit user ID
- `members`: LIST<STRING> (Queryable) - Array of CloudKit user IDs
- `environment`: STRING (Queryable) - "development" or "production"
- `isActive`: INT64 (Queryable) - Boolean as number
- `dateCreated`: DATE/TIME (Sortable)
- `settings`: STRING - JSON blob for organization settings

### 3. **TeamMember** Record Type
**Fields needed:**
- `id`: STRING (Queryable, Sortable) - UUID
- `name`: STRING (Queryable, Searchable, Sortable)
- `email`: STRING (Queryable, Searchable)
- `jobTitle`: STRING
- `organizationID`: STRING (Queryable) - Links to Organization
- `cloudKitUserID`: STRING (Queryable) - CloudKit user record ID
- `role`: STRING (Queryable) - "admin", "member", "viewer"
- `rates`: STRING - JSON encoded array of EmployeeRate objects
- `isActive`: INT64 (Queryable) - Boolean as number
- `dateAdded`: DATE/TIME (Sortable)
- `lastActive`: DATE/TIME (Sortable)
- `permissions`: LIST<STRING> - Array of permission strings

### 4. **Vendor** Record Type
**Fields needed:**
- `id`: STRING (Queryable, Sortable) - UUID
- `name`: STRING (Queryable, Searchable, Sortable) 
- `category`: STRING (Queryable, Sortable) - VendorCategory.rawValue
- `subcategories`: LIST<STRING> - Dynamic subcategories array
- `address`: STRING 
- `phone`: STRING
- `email`: STRING
- `notes`: STRING
- `organizationID`: STRING (Queryable) - Links to Organization
- `totalSpent`: DOUBLE (Sortable) - Cross-project spending total
- `isActive`: INT64 (Queryable) - Boolean as number
- `dateAdded`: DATE/TIME (Sortable)
- `lastUsed`: DATE/TIME (Sortable)
- `projectsUsed`: LIST<STRING> - Array of project IDs
- `createdBy`: STRING - CloudKit user ID of creator

### 5. **PaymentMethod** Record Type  
**Fields needed:**
- `id`: STRING (Queryable, Sortable) - UUID
- `name`: STRING (Queryable, Searchable, Sortable)
- `type`: STRING (Queryable, Sortable) - PaymentType.rawValue
- `cardBrand`: STRING - CardBrand.rawValue (optional)
- `lastFourDigits`: STRING 
- `nickname`: STRING
- `organizationID`: STRING (Queryable) - Links to Organization
- `totalSpent`: DOUBLE (Sortable) - Cross-project spending total
- `isActive`: INT64 (Queryable) - Boolean as number
- `dateAdded`: DATE/TIME (Sortable)
- `lastUsed`: DATE/TIME (Sortable)
- `accountNumber`: STRING - Masked account info
- `projectsUsed`: LIST<STRING> - Array of project IDs
- `createdBy`: STRING - CloudKit user ID of creator

### 6. **Project** Record Type (Enhanced)
**Add these fields to existing Project record:**
- `organizationID`: STRING (Queryable) - Links to Organization
- `sharedWithTeam`: INT64 (Queryable) - Boolean as number
- `teamMembers`: LIST<STRING> - Array of team member IDs with access
- `createdBy`: STRING - CloudKit user ID of creator
- `lastModifiedBy`: STRING - CloudKit user ID of last modifier
- `fullProjectData`: BYTES - Complete project JSON for data preservation

### 7. **Receipt** Record Type (Enhanced)
**Add these fields to existing Receipt record:**
- `organizationID`: STRING (Queryable) - Links to Organization
- `vendorID`: STRING (Queryable) - Links to Vendor record
- `paymentMethodID`: STRING (Queryable) - Links to PaymentMethod record
- `createdBy`: STRING - CloudKit user ID of creator
- `sharedWithTeam`: INT64 (Queryable) - Boolean as number

### 8. **ProgressLog** Record Type (Enhanced)
**Add these fields to existing ProgressLog record:**
- `organizationID`: STRING (Queryable) - Links to Organization
- `teamMemberIDs`: LIST<STRING> - Array of team member IDs who worked
- `createdBy`: STRING - CloudKit user ID of creator
- `sharedWithTeam`: INT64 (Queryable) - Boolean as number

### 9. **WorkHour** Record Type (Enhanced)
**Add these fields to existing WorkHour record:**
- `organizationID`: STRING (Queryable) - Links to Organization
- `teamMemberID`: STRING (Queryable) - Links to TeamMember record
- `createdBy`: STRING - CloudKit user ID of creator

### 10. **ProjectVendorUsage** Record Type
**For organization-wide spending analytics:**
- `id`: STRING (Queryable) - UUID
- `projectID`: STRING (Queryable, Sortable)
- `vendorID`: STRING (Queryable, Sortable)
- `organizationID`: STRING (Queryable)
- `totalSpent`: DOUBLE (Sortable)
- `receiptCount`: INT64 (Sortable)
- `firstUsed`: DATE/TIME (Sortable)
- `lastUsed`: DATE/TIME (Sortable)
- `lastUpdated`: DATE/TIME (Sortable)

### 11. **ProjectPaymentMethodUsage** Record Type
**For organization-wide spending analytics:**
- `id`: STRING (Queryable) - UUID
- `projectID`: STRING (Queryable, Sortable)
- `paymentMethodID`: STRING (Queryable, Sortable)
- `organizationID`: STRING (Queryable)
- `totalSpent`: DOUBLE (Sortable)
- `receiptCount`: INT64 (Sortable)
- `firstUsed`: DATE/TIME (Sortable)
- `lastUsed`: DATE/TIME (Sortable)
- `lastUpdated`: DATE/TIME (Sortable)

### 12. **TeamMemberProjectAssignment** Record Type (NEW)
**For project-level access control for all team members:**
- `id`: STRING (Queryable, Sortable) - UUID
- `userID`: STRING (Queryable, Sortable) - CloudKit user ID
- `organizationID`: STRING (Queryable, Sortable) - Organization ID
- `assignedProjects`: LIST<STRING> (Queryable) - Array of project IDs user can access
- `lastUpdated`: TIMESTAMP (Sortable) - When assignments were last changed
- `createdAt`: TIMESTAMP (Sortable) - When assignments were first created
- `createdBy`: STRING (Queryable) - Admin who created the assignments
- `environment`: STRING (Queryable) - "development" or "production"

**Purpose:** 
Controls which projects each team member can see and access. Admins see all projects automatically. Members, contractors, and viewers only see projects in their assignedProjects array.

### 13. **OrganizationInvite** Record Type (ENHANCED)
**Updated fields for project assignments:**
- `assignedProjects`: LIST<STRING> - Projects to assign to invited user
- `expiresAt`: TIMESTAMP (Queryable, Sortable) - When invite expires
- `acceptedAt`: TIMESTAMP (Sortable) - When invite was accepted
- `acceptedByUserID`: STRING (Queryable) - Who accepted the invite

## Zone-Based Data Isolation

### Organization Zones
Each organization gets its own CloudKit custom zone:
- Zone name: `org-shared-{organizationID}`
- Zone contains one OrganizationRoot record that gets shared
- All organization data stored in this zone
- Zone shared with all team members
- Automatic data isolation between organizations

### Data Flow
1. User joins organization → Gets access to organization zone via CloudKit share
2. Organization zone contains: OrganizationRoot, vendors, payment methods, team members, projects, receipts
3. All spending analytics work across shared data
4. Team members see consistent view of organization data

## CloudKit Sharing Requirements

### Critical Schema Points for Sharing:
1. **OrganizationRoot record MUST exist** - This is the root record that gets shared
2. **Cannot query `cloudkit.share` record type** - Use CloudKit sharing APIs instead
3. **Root record and CKShare must be saved atomically** - Use CKModifyRecordsOperation
4. **All queryable fields must be marked as "Queryable" in CloudKit Console**
5. **Cannot use `recordName` in queries** - It's not a queryable field

### Proper Share Detection:
Instead of querying `cloudkit.share`, use:

## Migration Strategy

### Phase 1: Create CloudKit Records
- Create all new record types in CloudKit dashboard
- Test with development environment first

### Phase 2: Migrate Local Data
- Read existing UserDefaults data
- Create corresponding CloudKit records
- Assign to current organization
- Verify data integrity

### Phase 3: Update Services
- Replace UserDefaults-based services with CloudKit services
- Implement offline caching for performance
- Add conflict resolution for concurrent edits

### Phase 4: Team Sharing
- Enable zone sharing for organizations
- Test invite flow and data access
- Verify spending analytics work across team members

## Security & Permissions

### Organization Admin
- Can invite/remove team members
- Can edit all organization data
- Can manage vendors and payment methods
- Full access to all projects and spending data

### Team Member
- Can view all organization data
- Can add receipts and progress logs
- Can create new vendors/payment methods
- Cannot remove other team members

### Viewer (Optional)
- Read-only access to organization data
- Cannot edit or add data
- Useful for accountants or clients

## Analytics Requirements

### Organization-Wide Analytics
Team members need access to:
- Total spending by vendor across all projects
- Total spending by payment method across all projects
- Spending trends over time
- Receipt details with photos and notes
- Project-specific breakdowns
- Team member hours and rates

### Key Queries Needed
- "Show all Home Depot receipts from last month"
- "Show all Chase credit card transactions"
- "Show Kevin's hours across all projects"
- "Show material costs vs labor costs by project"
- "Show which projects are over budget"

This ensures your accountant can see exactly what you described: spending at Home Depot between specific dates using specific payment methods, all in a collaborative environment.

## Missing Record Types to Add

### 1. **ReceiptPhoto** Record Type
**Fields needed:**
- `id`: STRING (Queryable, Sortable) - UUID
- `receiptID`: STRING (Queryable) - Links to Receipt
- `photo`: BINARY - Receipt photo
- `dateAdded`: DATE/TIME (Sortable)
- `createdBy`: STRING - CloudKit user ID of creator

## Project Permission Model

### Role-Based Access:
- **Admin**: Full access to all organization projects, can manage team assignments
- **Member**: Edit access to assigned projects only, can add receipts/progress logs
- **Contractor**: Edit access to assigned projects only, limited scope
- **Viewer**: Read-only access to assigned projects only

### Project Assignment Rules:
1. **New projects**: Creator is auto-assigned (unless admin)
2. **Invites**: Admin selects which projects to assign to new team member
3. **Assignments**: Can be changed by admin at any time
4. **No assignments**: User sees "Contact admin for project access" message

### Security Benefits:
1. **Data isolation**: Team members only see relevant projects
2. **Client privacy**: Contractors can't see other clients' projects
3. **Scalability**: Large organizations can segment teams by project
4. **Flexibility**: Easy to reassign team members to different projects

## Migration Notes

### Existing Organizations:
1. Current team members will need project assignments created
2. Admins retain full access automatically
3. Non-admin users may temporarily see no projects until assigned

### Recommended Migration Flow:
1. Deploy new schema
2. Admin assigns all current team members to all current projects
3. Future invites will specify project assignments upfront

This ensures maximum security and data isolation while maintaining flexibility for different team structures.