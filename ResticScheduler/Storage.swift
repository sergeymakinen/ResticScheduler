import Foundation
import ResticSchedulerMacro

extension UserDefaultValues {
    @UserDefaultEntry("BackupFrequency")
    var backupFrequency: Int = 86400

    @UserDefaultEntry("ResticRepository")
    var repository: String = FileManager.default.temporaryDirectory.path(percentEncoded: false)

    @UserDefaultEntry("ResticS3AccessKeyId")
    var s3AccessKeyId: String? = nil

    @UserDefaultEntry("ResticRESTUsername")
    var restUsername: String? = nil

    @UserDefaultEntry("ResticBinary")
    var binary: String? = nil

    @UserDefaultEntry("ResticHost")
    var host: String? = nil

    @UserDefaultEntry("ResticArguments")
    var arguments: [String] = ["--one-file-system", "--exclude-caches"]

    @UserDefaultEntry("ResticIncludes")
    var includes: [String] = []

    @UserDefaultEntry("ResticExcludes")
    var excludes: [String] = []

    @UserDefaultEntry("LastSuccessfulBackupDate")
    var lastSuccessfulBackupDate: Date? = nil
    
    @UserDefaultEntry("BeforeBackupHook")
    var beforeBackupHook: Hook? = nil
    
    @UserDefaultEntry("OnSuccessHook")
    var onSuccessHook: Hook? = nil
    
    @UserDefaultEntry("OnFailureHook")
    var onFailureHook: Hook? = nil
}

extension KeychainPasswordValues {
    @KeychainPasswordEntry("ResticS3SecretAccessKey")
    var s3SecretAccessKey: String? = nil

    @KeychainPasswordEntry("ResticRESTPassword")
    var restPassword: String? = nil

    @KeychainPasswordEntry("ResticPassword")
    var password: String = ""
}
