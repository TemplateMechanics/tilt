import { createApiRef, ConfigApi, DiscoveryApi, FetchApi } from '@backstage/core-plugin-api';

// =============================================================================
// Types for Tilt API responses
// =============================================================================

export interface TiltResource {
  name: string;
  type: string;
  runtimeStatus: 'ok' | 'pending' | 'error' | 'not_applicable';
  updateStatus: 'ok' | 'pending' | 'error' | 'not_applicable';
  buildHistory: TiltBuild[];
  endpointLinks: TiltLink[];
  labels: string[];
  queued: boolean;
  hasPendingChanges: boolean;
  disabled: boolean;
}

export interface TiltBuild {
  startTime: string;
  finishTime?: string;
  error?: string;
  spanId: string;
}

export interface TiltLink {
  url: string;
  name?: string;
}

// =============================================================================
// Types for Infrastructure Config (tilt-config.json)
// =============================================================================

export type AppGroup = 'crossplane_apps' | 'flux_apps' | 'raw_apps';

export interface AppConfig {
  enabled: boolean;
  description: string;
  category: string;
  tested: boolean;
}

export interface InfraConfig {
  crossplane_apps: Record<string, AppConfig>;
  flux_apps: Record<string, AppConfig>;
  raw_apps: Record<string, AppConfig>;
}

/** Flat view of a service for the dashboard */
export interface InfraService {
  name: string;
  group: AppGroup;
  enabled: boolean;
  description: string;
  category: string;
  tested: boolean;
  /** Runtime status from Tilt API (if service is running) */
  runtimeStatus?: 'ok' | 'pending' | 'error' | 'not_applicable';
  updateStatus?: 'ok' | 'pending' | 'error' | 'not_applicable';
  links?: TiltLink[];
}

/** Category grouping for the dashboard */
export interface InfraCategory {
  name: string;
  services: InfraService[];
}

// =============================================================================
// API Interfaces
// =============================================================================

export interface TiltApiInterface {
  // Tilt runtime API
  getResources(): Promise<TiltResource[]>;
  getResource(name: string): Promise<TiltResource>;
  triggerResource(name: string): Promise<void>;
  enableResource(name: string, enabled: boolean): Promise<void>;
  getResourceLogs(name: string): Promise<string>;

  // Infrastructure config API
  getInfraConfig(): Promise<InfraConfig>;
  setServiceEnabled(group: AppGroup, service: string, enabled: boolean): Promise<void>;
  bulkSetServices(changes: Array<{ group: AppGroup; service: string; enabled: boolean }>): Promise<void>;
  getInfraServices(): Promise<InfraService[]>;
  getInfraCategories(): Promise<InfraCategory[]>;
}

export const tiltApiRef = createApiRef<TiltApiInterface>({
  id: 'plugin.tilt.api',
});

// =============================================================================
// Implementation
// =============================================================================

export class TiltClient implements TiltApiInterface {
  private readonly discoveryApi: DiscoveryApi;
  private readonly fetchApi: FetchApi;

  constructor(options: { configApi: ConfigApi; discoveryApi: DiscoveryApi; fetchApi: FetchApi }) {
    this.discoveryApi = options.discoveryApi;
    this.fetchApi = options.fetchApi;
  }

  /**
   * Resolve the Tilt API URL via the Backstage proxy plugin.
   * All requests are routed through the backend proxy to avoid
   * mixed-content and CORS issues from the browser.
   */
  private async getTiltApiUrl(): Promise<string> {
    const proxyUrl = await this.discoveryApi.getBaseUrl('proxy');
    return `${proxyUrl}/tilt-api`;
  }

  /**
   * Resolve the config server URL via the Backstage proxy plugin.
   * In K8s, this routes through the backend to the in-cluster Service.
   */
  private async getConfigServerUrl(): Promise<string> {
    const proxyUrl = await this.discoveryApi.getBaseUrl('proxy');
    return `${proxyUrl}/tilt-config`;
  }

  // ---------------------------------------------------------------------------
  // Tilt Runtime API
  // ---------------------------------------------------------------------------

  async getResources(): Promise<TiltResource[]> {
    const tiltUrl = await this.getTiltApiUrl();
    const response = await this.fetchApi.fetch(`${tiltUrl}/api/view`, {
      headers: { Accept: 'application/json' },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch Tilt resources: ${response.statusText}`);
    }
    
    const data = await response.json();
    return this.parseResources(data);
  }

  async getResource(name: string): Promise<TiltResource> {
    const resources = await this.getResources();
    const resource = resources.find(r => r.name === name);
    
    if (!resource) {
      throw new Error(`Resource ${name} not found`);
    }
    
    return resource;
  }

  async triggerResource(name: string): Promise<void> {
    const tiltUrl = await this.getTiltApiUrl();
    const response = await this.fetchApi.fetch(`${tiltUrl}/api/trigger`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        manifest_names: [name],
        build_reason: 16, // Manual trigger
      }),
    });
    
    if (!response.ok) {
      throw new Error(`Failed to trigger resource ${name}: ${response.statusText}`);
    }
  }

  async enableResource(name: string, enabled: boolean): Promise<void> {
    const tiltUrl = await this.getTiltApiUrl();
    const response = await this.fetchApi.fetch(`${tiltUrl}/api/override`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name,
        disableSource: enabled ? null : { configMap: { name: `${name}-disable`, key: 'isDisabled' } },
      }),
    });
    
    if (!response.ok) {
      throw new Error(`Failed to ${enabled ? 'enable' : 'disable'} resource ${name}: ${response.statusText}`);
    }
  }

  async getResourceLogs(name: string): Promise<string> {
    const tiltUrl = await this.getTiltApiUrl();
    const response = await this.fetchApi.fetch(`${tiltUrl}/api/logs?name=${encodeURIComponent(name)}`, {
      headers: { Accept: 'text/plain' },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch logs for ${name}: ${response.statusText}`);
    }
    
    return response.text();
  }

  // ---------------------------------------------------------------------------
  // Infrastructure Config API (talks to config-server.py on port 10351)
  // ---------------------------------------------------------------------------

  async getInfraConfig(): Promise<InfraConfig> {
    const configUrl = await this.getConfigServerUrl();
    const response = await this.fetchApi.fetch(`${configUrl}/config`, {
      headers: { Accept: 'application/json' },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch infra config: ${response.statusText}`);
    }

    return response.json();
  }

  async setServiceEnabled(group: AppGroup, service: string, enabled: boolean): Promise<void> {
    const patch = {
      [group]: {
        [service]: { enabled },
      },
    };

    const configUrl = await this.getConfigServerUrl();
    const response = await this.fetchApi.fetch(`${configUrl}/config`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(patch),
    });

    if (!response.ok) {
      throw new Error(`Failed to update ${group}.${service}: ${response.statusText}`);
    }
  }

  async bulkSetServices(changes: Array<{ group: AppGroup; service: string; enabled: boolean }>): Promise<void> {
    // Build a single patch from all changes
    const patch: Record<string, Record<string, { enabled: boolean }>> = {};
    for (const { group, service, enabled } of changes) {
      if (!patch[group]) patch[group] = {};
      patch[group][service] = { enabled };
    }

    const configUrl = await this.getConfigServerUrl();
    const response = await this.fetchApi.fetch(`${configUrl}/config`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(patch),
    });

    if (!response.ok) {
      throw new Error(`Failed to apply bulk config changes: ${response.statusText}`);
    }
  }

  /** Get a flat list of all services with merged runtime status from Tilt */
  async getInfraServices(): Promise<InfraService[]> {
    const [config, resources] = await Promise.all([
      this.getInfraConfig(),
      this.getResources().catch(() => [] as TiltResource[]),
    ]);

    const resourceMap = new Map(resources.map(r => [r.name, r]));
    const services: InfraService[] = [];

    for (const group of ['crossplane_apps', 'flux_apps', 'raw_apps'] as AppGroup[]) {
      const groupConfig = config[group] || {};
      for (const [name, appConfig] of Object.entries(groupConfig)) {
        // Try to find matching Tilt resource
        const tiltResource = resourceMap.get(name) || resourceMap.get(`${name}-app`) || resourceMap.get(`${name}-status`);
        services.push({
          name,
          group,
          enabled: appConfig.enabled,
          description: appConfig.description || name,
          category: appConfig.category || 'Other',
          tested: appConfig.tested ?? false,
          runtimeStatus: tiltResource?.runtimeStatus,
          updateStatus: tiltResource?.updateStatus,
          links: tiltResource?.endpointLinks,
        });
      }
    }

    return services;
  }

  /** Get services grouped by category */
  async getInfraCategories(): Promise<InfraCategory[]> {
    const services = await this.getInfraServices();
    const categoryMap = new Map<string, InfraService[]>();

    for (const service of services) {
      const existing = categoryMap.get(service.category) || [];
      existing.push(service);
      categoryMap.set(service.category, existing);
    }

    // Sort categories in a sensible order
    const categoryOrder = [
      'Infrastructure', 'Developer Portal', 'Security & Policy', 'Observability',
      'Databases', 'Identity & Workflow', 'AI/ML', 'CI/CD', 'Messaging',
      'Cloud Emulators', 'Dev Tools', 'Demo Apps', 'Experimental',
    ];

    return categoryOrder
      .filter(cat => categoryMap.has(cat))
      .map(cat => ({ name: cat, services: categoryMap.get(cat)! }))
      .concat(
        // Include any categories not in the predefined order
        [...categoryMap.entries()]
          .filter(([cat]) => !categoryOrder.includes(cat))
          .map(([name, services]) => ({ name, services })),
      );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private parseResources(data: any): TiltResource[] {
    // Tilt API /api/view returns uiResources at the top level
    const uiResources = data?.uiResources || [];
    
    return uiResources.map((r: any) => ({
      name: r.metadata?.name || 'unknown',
      type: r.status?.specs?.[0]?.type || 'unknown',
      runtimeStatus: r.status?.runtimeStatus || 'not_applicable',
      updateStatus: r.status?.updateStatus || 'not_applicable',
      buildHistory: (r.status?.buildHistory || []).map((b: any) => ({
        startTime: b.startTime,
        finishTime: b.finishTime,
        error: b.error,
        spanId: b.spanID,
      })),
      endpointLinks: (r.status?.endpointLinks || []).map((l: any) => ({
        url: l.url,
        name: l.name,
      })),
      labels: r.metadata?.labels ? Object.keys(r.metadata.labels) : [],
      queued: r.status?.queued || false,
      hasPendingChanges: r.status?.hasPendingChanges || false,
      disabled: r.status?.disableStatus?.state === 'Disabled',
    }));
  }
}
