DEFINE SCHEMA

    CREATE ROLE member;
    CREATE ROLE viewer;

    RECORD TYPE Organization (
        "___createTime"  TIMESTAMP,
        "___createdBy"   REFERENCE,
        "___etag"        STRING,
        "___modTime"     TIMESTAMP,
        "___modifiedBy"  REFERENCE,
        "___recordID"    REFERENCE QUERYABLE,
        adminUserID      STRING QUERYABLE,
        createdAt        TIMESTAMP,
        dateCreated      TIMESTAMP SORTABLE,
        environment      STRING QUERYABLE,
        id               STRING QUERYABLE SEARCHABLE SORTABLE,
        inviteToken      STRING QUERYABLE SEARCHABLE SORTABLE,
        isActive         STRING QUERYABLE,
        isActiveV2       INT64,
        maxMembers       STRING,
        maxMembersV2     INT64,
        memberRoles      STRING,
        members          LIST<STRING> QUERYABLE SEARCHABLE SORTABLE,
        name             STRING QUERYABLE SEARCHABLE SORTABLE,
        orgID            STRING QUERYABLE,
        orgName          STRING,
        organizationID   STRING,
        pendingInvites   LIST<STRING>,
        settings         STRING,
        subscriptionType STRING,
        GRANT READ, WRITE TO "_creator",
        GRANT READ, CREATE TO "_icloud",
        GRANT READ, WRITE TO member
    );