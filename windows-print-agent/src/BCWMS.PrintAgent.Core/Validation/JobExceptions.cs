namespace BCWMS.PrintAgent.Core.Validation;

public sealed class PermanentJobException : Exception
{
    public PermanentJobException(string message) : base(message) { }
    public PermanentJobException(string message, Exception innerException) : base(message, innerException) { }
}

public sealed class TransientJobException : Exception
{
    public TransientJobException(string message) : base(message) { }
    public TransientJobException(string message, Exception innerException) : base(message, innerException) { }
}

public sealed class AgentConfigurationException : Exception
{
    public AgentConfigurationException(string message) : base(message) { }
    public AgentConfigurationException(string message, Exception innerException) : base(message, innerException) { }
}

public sealed class OutcomeUncertainException : Exception
{
    public OutcomeUncertainException(string message) : base(message) { }
}
