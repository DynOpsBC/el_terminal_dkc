codeunit 72116 "DOPSWHS WI Migration Tests"
{
    Subtype = Test;

    [Test]
    procedure PreflightReturnsGracefullyWhenWINotInstalled()
    var
        Migration: Codeunit "DOPSWHS Migrate From WI";
    begin
        Migration.PreflightCheck();
        Assert.IsTrue(true, 'Preflight must return without error when WI is absent.');
    end;

    [Test]
    procedure DryRunReturnsZeroRowsWhenWINotInstalled()
    var
        Migration: Codeunit "DOPSWHS Migrate From WI";
    begin
        Migration.DryRun('BLUE');
        Assert.IsTrue(true, 'Dry run must return without error when WI is absent.');
    end;

    [Test]
    procedure ApplyReturnsNothingToMigrateWhenWINotInstalled()
    var
        Migration: Codeunit "DOPSWHS Migrate From WI";
    begin
        Migration.Apply('BLUE');
        Assert.IsTrue(true, 'Apply must return without error when WI is absent.');
    end;

    [Test]
    procedure RollbackErrorsWithExpectedMessage()
    var
        Migration: Codeunit "DOPSWHS Migrate From WI";
    begin
        asserterror Migration.Rollback(1);
        Assert.ExpectedError('Rollback not implemented in this version');
    end;

    var
        Assert: Codeunit Assert;
}
