export type TenantConfig = {
  tenantId: string;
  hmacSecret: string;
  fcmTokens: Record<string, string>;
  signalRHub: string;
};

export class TenantRegistry {
  static fromEnv(): TenantRegistry {
    return new TenantRegistry(JSON.parse(process.env.TENANT_CONFIG_JSON ?? "{}"));
  }

  constructor(private readonly tenants: Record<string, TenantConfig>) {}

  get(tenantId: string): TenantConfig {
    const config = this.tenants[tenantId] ?? this.tenants.default;
    if (!config) throw new Error(`Tenant ${tenantId} is not configured`);
    return config;
  }
}
