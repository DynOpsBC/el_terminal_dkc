page 72372 "DOPSWHS Azure Print Secrets"
{
    Caption = 'Configure Azure Print Secrets';
    PageType = StandardDialog;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Credentials)
            {
                Caption = 'Credentials';
                field(BlobUploadSas; BlobUploadSasValue)
                {
                    Caption = 'Blob Create/Write SAS';
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                    ToolTip = 'Container-scoped HTTPS SAS using stored policy bc-upload, or a SAS containing only Create and Write permissions. Leave blank to keep the current value.';
                }
                field(BlobSasExpiresAt; BlobSasExpiresAtValue)
                {
                    Caption = 'Blob SAS Expires At (UTC)';
                    ApplicationArea = All;
                    ToolTip = 'Required when entering a new Blob SAS token. Enter the UTC expiry reported by the deployment script. Leave blank when keeping the existing Blob SAS.';
                }
                field(JobsSharedKey; JobsSharedKeyValue)
                {
                    Caption = 'Jobs Send Shared Key';
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                    ToolTip = 'SharedAccessKey for the queue-scoped bc-send-jobs Send policy. Leave blank to keep the current value.';
                }
                field(StatusSharedKey; StatusSharedKeyValue)
                {
                    Caption = 'Status Listen Shared Key';
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                    ToolTip = 'SharedAccessKey for the queue-scoped bc-listen-status Listen policy. Leave blank to keep the current value.';
                }
            }
        }
    }

    [NonDebuggable]
    procedure GetBlobUploadSas(): Text
    begin
        exit(BlobUploadSasValue);
    end;

    [NonDebuggable]
    procedure GetJobsSharedKey(): Text
    begin
        exit(JobsSharedKeyValue);
    end;

    procedure GetBlobSasExpiresAt(): DateTime
    begin
        exit(BlobSasExpiresAtValue);
    end;

    [NonDebuggable]
    procedure GetStatusSharedKey(): Text
    begin
        exit(StatusSharedKeyValue);
    end;

    var
        BlobUploadSasValue: Text;
        BlobSasExpiresAtValue: DateTime;
        JobsSharedKeyValue: Text;
        StatusSharedKeyValue: Text;
}
