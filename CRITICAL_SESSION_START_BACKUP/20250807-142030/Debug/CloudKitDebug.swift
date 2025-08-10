import CloudKit
import os

public struct CloudKitDebug {
    public static func log(_ record: CKRecord) {
        #if DEBUG
        os_log("CKRecord ▷ type:%{public}@ id:%{public}@", record.recordType, record.recordID.recordName)
        for key in record.allKeys() {
            os_log("  • %{public}@ = %{public}@", key, String(describing: record[key]!))
        }
        #endif
    }

    public static func log(error: Error) {
        #if DEBUG
        os_log("CloudKit Error: %{public}@", String(describing: error))
        #endif
    }
}
