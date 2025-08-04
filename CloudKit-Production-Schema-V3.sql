DEFINE SCHEMA

    CREATE ROLE admin;
    CREATE ROLE member;
    CREATE ROLE contractor;
    CREATE ROLE viewer;

    -- Organization Management
    RECORD TYPE Organization (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Core Organization Fields
        id                   STRING QUERYABLE SEARCHABLE SORTABLE,
        name                 STRING QUERYABLE SEARCHABLE SORTABLE,
        adminUserID          STRING QUERYABLE,
        createdAt            TIMESTAMP SORTABLE,
        isActive             INT64,
        environment          STRING QUERYABLE,
        
        -- Business Information
        businessType         STRING,
        businessPhone        STRING,
        businessEmail        STRING QUERYABLE,
        website              STRING,
        businessEIN          STRING,
        businessLicense      STRING,
        
        -- Address Information
        businessStreet       STRING,
        businessCity         STRING,
        businessState        STRING,
        businessZip          STRING,
        businessCountry      STRING,
        
        -- Member Management
        members              LIST<STRING> QUERYABLE,
        memberRoles          BYTES, -- JSON encoded role mappings
        pendingInvites       LIST<STRING>,
        maxMembers           INT64,
        
        -- Settings and Configuration
        settings             BYTES, -- JSON encoded settings
        subscriptionType     STRING,
        subscriptionStatus   STRING,
        billingCycle         STRING,
        
        -- CloudKit Sharing
        inviteToken          STRING QUERYABLE SEARCHABLE,
        shareURL             STRING,
        
        GRANT READ, WRITE TO "_creator",
        GRANT READ, CREATE TO "_icloud",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Organization Root for CloudKit Sharing
    RECORD TYPE OrganizationRoot (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        organizationID       STRING QUERYABLE SORTABLE,
        name                 STRING QUERYABLE SEARCHABLE SORTABLE,
        description          STRING,
        createdAt            TIMESTAMP SORTABLE,
        zoneVersion          INT64,
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- User Management
    RECORD TYPE RHEIRUser (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE QUERYABLE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        userID               STRING QUERYABLE SEARCHABLE,
        email                STRING QUERYABLE SEARCHABLE,
        name                 STRING QUERYABLE SEARCHABLE,
        appleUserID          STRING QUERYABLE,
        
        -- Profile Information
        phone                STRING,
        profileImageURL      STRING,
        timeZone             STRING,
        language             STRING,
        
        -- App Settings
        notificationSettings BYTES, -- JSON encoded
        preferences          BYTES, -- JSON encoded
        lastActiveAt         TIMESTAMP,
        
        -- Subscription and Organization
        currentOrganizationID STRING QUERYABLE,
        organizationMemberships BYTES, -- JSON encoded list of org memberships
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"
    );

    -- Organization Invitations
    RECORD TYPE OrganizationInvite (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        organizationID       STRING QUERYABLE,
        inviteToken          STRING QUERYABLE SEARCHABLE,
        inviteeEmail         STRING QUERYABLE,
        inviterUserID        STRING QUERYABLE,
        role                 STRING QUERYABLE,
        status               STRING QUERYABLE, -- pending, accepted, expired, cancelled
        
        -- Project Assignments for Contractors
        assignedProjectIDs   LIST<STRING>,
        
        -- Timing
        createdAt            TIMESTAMP QUERYABLE SORTABLE,
        expiresAt            TIMESTAMP QUERYABLE SORTABLE,
        acceptedAt           TIMESTAMP,
        
        environment          STRING QUERYABLE,
        
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member
    );

    -- Organization Membership
    RECORD TYPE OrganizationMember (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        organizationID       STRING QUERYABLE,
        userID               STRING QUERYABLE,
        email                STRING QUERYABLE,
        role                 STRING QUERYABLE, -- admin, member, contractor, viewer
        status               STRING QUERYABLE, -- active, suspended, terminated
        
        -- Joining Information
        invitedBy            STRING QUERYABLE,
        joinedAt             TIMESTAMP SORTABLE,
        lastActiveAt         TIMESTAMP,
        
        -- Project Access (for contractors)
        assignedProjectIDs   LIST<STRING>,
        
        environment          STRING QUERYABLE,
        
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member
    );

    -- Team Member Management
    RECORD TYPE TeamMember (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Basic Information
        id                   STRING QUERYABLE SEARCHABLE SORTABLE,
        name                 STRING QUERYABLE SEARCHABLE SORTABLE,
        email                STRING QUERYABLE SEARCHABLE SORTABLE,
        phone                STRING,
        jobTitle             STRING QUERYABLE SEARCHABLE SORTABLE,
        
        -- Employment Details
        employmentType       STRING QUERYABLE, -- employee, contractor, consultant, intern
        employmentStatus     STRING QUERYABLE, -- active, betweenProjects, completed, terminated, suspended, onLeave
        hireDate             TIMESTAMP SORTABLE,
        terminationDate      TIMESTAMP,
        terminationReason    STRING,
        terminationType      STRING, -- voluntary, involuntary, endOfContract, layoff
        
        -- Address Information
        street               STRING,
        city                 STRING,
        state                STRING,
        zip                  STRING,
        country              STRING,
        
        -- Emergency Contact
        emergencyContact     STRING,
        emergencyPhone       STRING,
        emergencyRelationship STRING,
        
        -- Pay Rates and Financial
        rates                BYTES QUERYABLE, -- JSON encoded EmployeeRate array
        defaultRate          DOUBLE,
        
        -- App Access and Permissions
        hasAppAccess         INT64,
        appUserID            STRING QUERYABLE, -- Links to RHEIRUser
        cloudKitUserID       STRING QUERYABLE,
        role                 STRING QUERYABLE, -- admin, member, contractor, viewer
        permissions          LIST<STRING>,
        
        -- Documentation and Compliance
        w9OnFile             INT64,
        i9OnFile             INT64,
        taxID                STRING, -- Encrypted/masked
        
        -- Organization and Project Assignment
        organizationID       STRING QUERYABLE SEARCHABLE SORTABLE,
        assignedProjectIDs   LIST<STRING>,
        
        -- Metadata
        notes                STRING,
        isActive             INT64 QUERYABLE SORTABLE,
        isArchived           INT64,
        createdBy            STRING QUERYABLE,
        dateAdded            TIMESTAMP SORTABLE,
        lastActive           TIMESTAMP SORTABLE,
        lastModified         TIMESTAMP,
        
        environment          STRING QUERYABLE,
        
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Project Management
    RECORD TYPE Project (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Basic Project Information
        id                   STRING QUERYABLE SEARCHABLE SORTABLE,
        name                 STRING QUERYABLE SEARCHABLE SORTABLE,
        client               STRING QUERYABLE SEARCHABLE SORTABLE,
        clientContact        STRING,
        clientPhone          STRING QUERYABLE SEARCHABLE SORTABLE,
        clientEmail          STRING,
        
        -- Project Details
        description          STRING,
        notes                STRING QUERYABLE SEARCHABLE SORTABLE,
        status               STRING QUERYABLE, -- planning, active, onHold, completed, cancelled
        priority             STRING QUERYABLE, -- low, medium, high, urgent
        
        -- Location Information
        street               STRING QUERYABLE SEARCHABLE SORTABLE,
        city                 STRING QUERYABLE SEARCHABLE SORTABLE,
        state                STRING QUERYABLE SEARCHABLE SORTABLE,
        zip                  STRING QUERYABLE SEARCHABLE SORTABLE,
        country              STRING,
        location             LOCATION,
        
        -- Timeline
        startDate            TIMESTAMP QUERYABLE SORTABLE,
        endDate              TIMESTAMP QUERYABLE SORTABLE,
        estimatedDuration    INT64, -- days
        actualStartDate      TIMESTAMP,
        actualEndDate        TIMESTAMP,
        
        -- Budget Information
        totalBudget          DOUBLE QUERYABLE SORTABLE,
        materialCost         DOUBLE QUERYABLE SORTABLE,
        laborCost            DOUBLE QUERYABLE SORTABLE,
        generalConditions    DOUBLE QUERYABLE SORTABLE,
        contingency          DOUBLE QUERYABLE SORTABLE,
        profit               DOUBLE QUERYABLE SORTABLE,
        spentContingency     DOUBLE QUERYABLE SORTABLE,
        actualTotalCost      DOUBLE,
        
        -- Team and Access Management
        projectManager       STRING QUERYABLE, -- TeamMember ID
        assignedUserIDs      LIST<STRING>, -- RHEIRUser IDs
        assignedTeamMemberIDs LIST<STRING>, -- TeamMember IDs
        accessLevel          STRING QUERYABLE, -- organization, restricted, private
        
        -- Organization and Sharing
        organizationID       STRING QUERYABLE,
        createdBy            STRING QUERYABLE,
        isShared             INT64 QUERYABLE SORTABLE,
        sharedWithTeam       INT64 QUERYABLE,
        
        -- Data Storage
        fullProjectData      BYTES, -- Complete JSON serialized project
        
        -- Metadata
        createdTimestamp     TIMESTAMP QUERYABLE SORTABLE,
        lastModified         TIMESTAMP QUERYABLE SORTABLE,
        lastModifiedBy       STRING QUERYABLE SEARCHABLE SORTABLE,
        lastSyncedAt         TIMESTAMP,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO "_creator",
        GRANT READ, CREATE TO "_icloud",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Task Management
    RECORD TYPE ProjectTask (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Basic Task Information
        id                   STRING QUERYABLE SEARCHABLE,
        title                STRING QUERYABLE SEARCHABLE,
        description          STRING,
        notes                STRING,
        
        -- Task Classification
        category             STRING QUERYABLE, -- foundation, framing, electrical, plumbing, etc.
        priority             STRING QUERYABLE, -- low, medium, high, urgent
        status               STRING QUERYABLE, -- notStarted, inProgress, completed, blocked
        
        -- Assignment and Responsibility
        assignedEmployeeIDs  LIST<STRING>,
        assignedTeamMemberIDs LIST<STRING>,
        createdBy            STRING QUERYABLE,
        
        -- Timeline
        createdAt            TIMESTAMP SORTABLE,
        dueDate              TIMESTAMP QUERYABLE SORTABLE,
        estimatedHours       DOUBLE,
        actualHours          DOUBLE,
        
        -- Completion Information
        isCompleted          INT64 QUERYABLE,
        completedDate        TIMESTAMP,
        completedBy          LIST<STRING>, -- Who marked it complete
        completionNotes      STRING,
        
        -- Dependencies and Relationships
        dependsOnTaskIDs     LIST<STRING>,
        blockedByTaskIDs     LIST<STRING>,
        parentTaskID         STRING,
        
        -- Media and Documentation
        photoIDs             LIST<STRING>,
        attachmentURLs       LIST<STRING>,
        
        -- Project and Organization
        projectID            STRING QUERYABLE,
        organizationID       STRING QUERYABLE,
        
        -- Metadata
        lastSyncedAt         TIMESTAMP,
        lastModified         TIMESTAMP,
        
        environment          STRING QUERYABLE,
        
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor
    );

    -- Daily Progress Logging
    RECORD TYPE ProgressLog (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Basic Progress Information
        id                   STRING QUERYABLE,
        workDescription      STRING QUERYABLE,
        notes                STRING,
        description          STRING, -- Legacy field
        
        -- Categorization
        category             STRING QUERYABLE,
        taskID               STRING, -- Associated task if any
        
        -- Team Assignment
        employeeIDs          LIST<STRING> QUERYABLE,
        teamMemberIDs        LIST<STRING> QUERYABLE,
        createdBy            STRING QUERYABLE,
        
        -- Timing
        date                 STRING QUERYABLE, -- Legacy
        dateV2               TIMESTAMP QUERYABLE SORTABLE,
        logDate              TIMESTAMP QUERYABLE SORTABLE,
        
        -- Weather and Conditions
        weatherConditions    STRING,
        temperature          STRING,
        workingConditions    STRING,
        
        -- Progress Metrics
        percentComplete      DOUBLE,
        hoursWorked          DOUBLE,
        materialsUsed        STRING,
        
        -- Media Documentation
        photoIDs             LIST<STRING>,
        beforePhotos         LIST<STRING>,
        afterPhotos          LIST<STRING>,
        
        -- Project and Organization
        projectID            STRING QUERYABLE,
        organizationID       STRING QUERYABLE,
        
        -- Sharing and Access
        sharedWithTeam       INT64 QUERYABLE,
        isPublic             INT64,
        
        -- Custom Fields
        customFields         BYTES, -- JSON encoded custom data
        
        -- Metadata
        lastSyncedAt         TIMESTAMP,
        
        environment          STRING QUERYABLE,
        
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor
    );

    -- Time Tracking and Work Hours
    RECORD TYPE WorkHour (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Basic Time Information
        id                   STRING QUERYABLE,
        employee             STRING QUERYABLE, -- Employee name
        teamMemberID         STRING QUERYABLE, -- TeamMember ID
        
        -- Time Details
        date                 TIMESTAMP QUERYABLE SORTABLE,
        hours                DOUBLE QUERYABLE,
        startTime            TIMESTAMP,
        endTime              TIMESTAMP,
        
        -- Work Classification
        taskType             STRING QUERYABLE,
        description          STRING,
        taskCategory         STRING QUERYABLE,
        
        -- Rate and Payment
        rate                 DOUBLE QUERYABLE,
        hourlyRate           DOUBLE QUERYABLE,
        totalAmount          DOUBLE QUERYABLE,
        
        -- Approval and Payment Status
        isPaid               INT64 QUERYABLE,
        isApproved           INT64 QUERYABLE,
        approvedBy           STRING QUERYABLE,
        approvedAt           TIMESTAMP,
        
        -- Location and Context
        location             LOCATION,
        projectID            STRING QUERYABLE,
        organizationID       STRING QUERYABLE,
        
        -- Metadata
        createdBy            STRING QUERYABLE,
        notes                STRING,
        lastSyncedAt         TIMESTAMP,
        
        environment          STRING QUERYABLE,
        
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor
    );

    -- Advanced Time Entry (New Format)
    RECORD TYPE TimeEntry (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Time Information
        teamMemberID         STRING QUERYABLE,
        dateWorked           TIMESTAMP QUERYABLE SORTABLE,
        startTime            TIMESTAMP QUERYABLE SORTABLE,
        endTime              TIMESTAMP QUERYABLE SORTABLE,
        duration             DOUBLE QUERYABLE SORTABLE, -- in hours
        
        -- Work Details
        taskDescription      STRING,
        taskCategory         STRING QUERYABLE,
        notes                STRING,
        
        -- Financial
        hourlyRate           DOUBLE QUERYABLE,
        totalAmount          DOUBLE QUERYABLE SORTABLE,
        
        -- Status and Approval
        isApproved           INT64 QUERYABLE,
        isPaid               INT64 QUERYABLE,
        approvedBy           STRING QUERYABLE,
        approvedAt           TIMESTAMP,
        
        -- Location
        location             LOCATION,
        
        -- Project and Organization
        projectID            STRING QUERYABLE,
        organizationID       STRING QUERYABLE,
        
        -- Metadata
        createdBy            STRING QUERYABLE,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Receipt and Expense Management
    RECORD TYPE Receipt (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Basic Receipt Information
        id                   STRING QUERYABLE,
        amount               DOUBLE QUERYABLE SORTABLE,
        receiptDate          TIMESTAMP QUERYABLE SORTABLE,
        
        -- Vendor Information
        vendor               STRING QUERYABLE SEARCHABLE,
        vendorID             STRING QUERYABLE,
        
        -- Payment Information
        paymentMethodID      STRING QUERYABLE,
        paymentMethodName    STRING,
        
        -- Categorization
        category             STRING QUERYABLE,
        subcategory          STRING,
        expenseType          STRING QUERYABLE, -- material, labor, equipment, etc.
        
        -- Tax and Return Information
        taxAmount            DOUBLE,
        taxRate              DOUBLE,
        isReturn             INT64,
        returnAmount         DOUBLE,
        returnDate           TIMESTAMP,
        
        -- Description and Notes
        description          STRING,
        notes                STRING,
        itemDetails          STRING, -- Detailed list of items purchased
        
        -- Media and Documentation
        receiptImage         ASSET,
        photoIDs             LIST<STRING>,
        
        -- Approval and Processing
        isReimbursable       INT64,
        isApproved           INT64,
        approvedBy           STRING,
        approvedAt           TIMESTAMP,
        
        -- Project and Organization
        projectID            STRING QUERYABLE,
        organizationID       STRING QUERYABLE,
        
        -- Sharing and Access
        sharedWithTeam       INT64 QUERYABLE,
        uploadedBy           STRING QUERYABLE,
        
        -- Metadata
        lastSyncedAt         TIMESTAMP,
        
        environment          STRING QUERYABLE,
        
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor
    );

    -- Vendor Management
    RECORD TYPE Vendor (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Basic Vendor Information
        id                   STRING QUERYABLE SORTABLE,
        name                 STRING QUERYABLE SEARCHABLE SORTABLE,
        
        -- Contact Information
        email                STRING,
        phone                STRING,
        website              STRING,
        
        -- Address Information
        address              STRING,
        street               STRING,
        city                 STRING,
        state                STRING,
        zip                  STRING,
        country              STRING,
        
        -- Business Information
        businessType         STRING,
        taxID                STRING,
        licenseNumber        STRING,
        
        -- Categorization
        category             STRING QUERYABLE SORTABLE,
        subcategories        LIST<STRING>,
        services             LIST<STRING>,
        
        -- Relationship and Performance
        preferredVendor      INT64,
        rating               DOUBLE,
        notes                STRING,
        
        -- Financial Tracking
        totalSpent           DOUBLE SORTABLE,
        lastUsed             TIMESTAMP SORTABLE,
        projectsUsed         LIST<STRING>,
        
        -- Payment Terms
        paymentTerms         STRING,
        discountTerms        STRING,
        
        -- Organization and Status
        organizationID       STRING QUERYABLE,
        isActive             INT64 QUERYABLE,
        
        -- Metadata
        createdBy            STRING QUERYABLE,
        dateAdded            TIMESTAMP SORTABLE,
        lastUpdated          TIMESTAMP SORTABLE,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Payment Method Management
    RECORD TYPE PaymentMethod (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Basic Payment Method Information
        id                   STRING QUERYABLE SORTABLE,
        name                 STRING QUERYABLE SEARCHABLE SORTABLE,
        nickname             STRING,
        type                 STRING QUERYABLE SORTABLE, -- credit, debit, cash, check, etc.
        
        -- Card Information (for cards)
        cardBrand            STRING, -- Visa, MasterCard, etc.
        lastFourDigits       STRING,
        accountNumber        STRING, -- Encrypted/masked
        
        -- Bank Information (for checks/ACH)
        bankName             STRING,
        accountType          STRING, -- checking, savings, etc.
        routingNumber        STRING,
        
        -- Usage Tracking
        totalSpent           DOUBLE SORTABLE,
        lastUsed             TIMESTAMP SORTABLE,
        projectsUsed         LIST<STRING>,
        receiptCount         INT64,
        
        -- Organization and Status
        organizationID       STRING QUERYABLE,
        isActive             INT64 QUERYABLE,
        
        -- Metadata
        createdBy            STRING QUERYABLE,
        dateAdded            TIMESTAMP SORTABLE,
        lastUpdated          TIMESTAMP SORTABLE,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Change Order Management
    RECORD TYPE ChangeOrder (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Basic Change Order Information
        changeNumber         INT64 QUERYABLE SORTABLE,
        description          STRING,
        reason               STRING,
        
        -- Financial Impact
        amount               DOUBLE QUERYABLE SORTABLE,
        impactToBudget       DOUBLE,
        
        -- Schedule Impact
        impactToSchedule     STRING,
        daysAdded            INT64,
        newCompletionDate    TIMESTAMP,
        
        -- Approval Process
        status               STRING QUERYABLE, -- pending, approved, rejected, implemented
        clientApproval       INT64,
        approvedBy           STRING QUERYABLE,
        dateApproved         TIMESTAMP QUERYABLE SORTABLE,
        
        -- Documentation
        attachments          LIST<STRING>,
        justification        STRING,
        
        -- Project and Organization
        projectID            STRING QUERYABLE,
        organizationID       STRING QUERYABLE,
        
        -- Metadata
        createdBy            STRING QUERYABLE,
        dateCreated          TIMESTAMP QUERYABLE SORTABLE,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Communication Log
    RECORD TYPE CommunicationLog (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        -- Communication Details
        subject              STRING QUERYABLE SEARCHABLE,
        content              STRING,
        communicationType    STRING QUERYABLE, -- email, phone, meeting, text
        
        -- Participants
        recipientEmails      LIST<STRING>,
        participants         LIST<STRING>,
        
        -- Priority and Follow-up
        priority             STRING QUERYABLE, -- low, medium, high, urgent
        followUpRequired     INT64,
        followUpDate         TIMESTAMP,
        followUpCompleted    INT64,
        
        -- Documentation
        attachments          LIST<STRING>,
        
        -- Project and Organization
        projectID            STRING QUERYABLE,
        organizationID       STRING QUERYABLE,
        
        -- Metadata
        createdBy            STRING QUERYABLE,
        dateCreated          TIMESTAMP QUERYABLE SORTABLE,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Photo Management for Progress
    RECORD TYPE ProgressPhoto (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        progressLogID        STRING QUERYABLE,
        photo                ASSET,
        thumbnail            ASSET,
        photoOrder           INT64,
        caption              STRING,
        
        -- Location and Context
        gpsLocation          LOCATION,
        cameraAngle          STRING,
        photoType            STRING, -- before, during, after, overview, detail
        
        -- Organization
        organizationID       STRING QUERYABLE,
        
        -- Metadata
        uploadedBy           STRING QUERYABLE,
        uploadedAt           TIMESTAMP,
        fileSize             INT64,
        originalFilename     STRING,
        
        environment          STRING QUERYABLE,
        
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world",
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Photo Management for Receipts
    RECORD TYPE ReceiptPhoto (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        receiptID            STRING QUERYABLE,
        photo                ASSET,
        thumbnail            ASSET,
        photoOrder           INT64,
        
        -- Organization
        organizationID       STRING QUERYABLE,
        
        -- Metadata
        uploadedBy           STRING QUERYABLE,
        uploadedAt           TIMESTAMP,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Photo Management for Tasks
    RECORD TYPE TaskPhoto (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE QUERYABLE,
        
        taskID               STRING QUERYABLE,
        photo                ASSET,
        thumbnail            ASSET,
        photoOrder           INT64,
        caption              STRING,
        
        -- Organization
        organizationID       STRING QUERYABLE,
        
        -- Metadata
        uploadedBy           STRING QUERYABLE,
        uploadedAt           TIMESTAMP,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Analytics and Reporting
    RECORD TYPE OrganizationSpendingSummary (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE,
        
        organizationID       STRING QUERYABLE,
        summaryDate          TIMESTAMP QUERYABLE SORTABLE,
        
        -- Financial Summaries
        totalSpent           DOUBLE SORTABLE,
        projectBreakdown     BYTES, -- JSON encoded
        vendorBreakdown      BYTES, -- JSON encoded
        paymentMethodBreakdown BYTES, -- JSON encoded
        categoryBreakdown    BYTES, -- JSON encoded
        
        -- Metadata
        generatedBy          STRING QUERYABLE,
        lastUpdated          TIMESTAMP SORTABLE,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- Project Analytics
    RECORD TYPE ProjectVendorUsage (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE,
        
        id                   STRING QUERYABLE,
        projectID            STRING QUERYABLE SORTABLE,
        vendorID             STRING QUERYABLE SORTABLE,
        organizationID       STRING QUERYABLE,
        
        -- Usage Statistics
        totalSpent           DOUBLE SORTABLE,
        receiptCount         INT64 SORTABLE,
        firstUsed            TIMESTAMP SORTABLE,
        lastUsed             TIMESTAMP SORTABLE,
        lastUpdated          TIMESTAMP SORTABLE,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    RECORD TYPE ProjectPaymentMethodUsage (
        "___createTime"      TIMESTAMP,
        "___createdBy"       REFERENCE,
        "___etag"            STRING,
        "___modTime"         TIMESTAMP,
        "___modifiedBy"      REFERENCE,
        "___recordID"        REFERENCE,
        
        id                   STRING QUERYABLE,
        projectID            STRING QUERYABLE SORTABLE,
        paymentMethodID      STRING QUERYABLE SORTABLE,
        organizationID       STRING QUERYABLE,
        
        -- Usage Statistics
        totalSpent           DOUBLE SORTABLE,
        receiptCount         INT64 SORTABLE,
        firstUsed            TIMESTAMP SORTABLE,
        lastUsed             TIMESTAMP SORTABLE,
        lastUpdated          TIMESTAMP SORTABLE,
        
        environment          STRING QUERYABLE,
        
        GRANT READ, WRITE TO admin,
        GRANT READ, WRITE TO member,
        GRANT READ TO contractor,
        GRANT READ TO viewer
    );

    -- CloudKit Sharing Support
    RECORD TYPE "cloudkit.share" (
        "___createTime"               TIMESTAMP,
        "___createdBy"                REFERENCE,
        "___etag"                     STRING,
        "___modTime"                  TIMESTAMP,
        "___modifiedBy"               REFERENCE,
        "___recordID"                 REFERENCE,
        "cloudkit.thumbnailImageData" BYTES,
        "cloudkit.title"              STRING,
        "cloudkit.type"               STRING,
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"
    );

    -- Legacy Support (Keep for data migration)
    RECORD TYPE Employee (
        "___createTime" TIMESTAMP,
        "___createdBy"  REFERENCE,
        "___etag"       STRING,
        "___modTime"    TIMESTAMP,
        "___modifiedBy" REFERENCE,
        "___recordID"   REFERENCE QUERYABLE,
        createdAt       TIMESTAMP,
        email           STRING QUERYABLE SEARCHABLE SORTABLE,
        environment     STRING QUERYABLE,
        hourlyRate      DOUBLE,
        id              STRING QUERYABLE SEARCHABLE SORTABLE,
        isActive        INT64,
        isArchived      INT64 QUERYABLE SORTABLE,
        jobTitle        STRING,
        name            STRING QUERYABLE SORTABLE,
        organizationID  STRING QUERYABLE,
        rates           BYTES QUERYABLE SORTABLE,
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"
    );

    -- Test Record for Development
    RECORD TYPE TestRecord (
        "___createTime" TIMESTAMP,
        "___createdBy"  REFERENCE,
        "___etag"       STRING,
        "___modTime"    TIMESTAMP,
        "___modifiedBy" REFERENCE,
        "___recordID"   REFERENCE,
        environment     STRING QUERYABLE,
        testField       STRING QUERYABLE SEARCHABLE SORTABLE,
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"
    );