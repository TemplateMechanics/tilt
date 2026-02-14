import { createApiRef, ConfigApi } from '@backstage/core-plugin-api';

// Types for Tilt API responses
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

export interface TiltApiInterface {
  getResources(): Promise<TiltResource[]>;
  getResource(name: string): Promise<TiltResource>;
  triggerResource(name: string): Promise<void>;
  enableResource(name: string, enabled: boolean): Promise<void>;
  getResourceLogs(name: string): Promise<string>;
}

export const tiltApiRef = createApiRef<TiltApiInterface>({
  id: 'plugin.tilt.api',
});

export class TiltClient implements TiltApiInterface {
  private readonly configApi: ConfigApi;
  private readonly baseUrl: string;

  constructor(options: { configApi: ConfigApi }) {
    this.configApi = options.configApi;
    this.baseUrl = this.configApi.getOptionalString('tilt.baseUrl') ?? 'http://localhost:10350';
  }

  async getResources(): Promise<TiltResource[]> {
    const response = await fetch(`${this.baseUrl}/api/view`, {
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
    const response = await fetch(`${this.baseUrl}/api/trigger`, {
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
    const response = await fetch(`${this.baseUrl}/api/override`, {
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
    const response = await fetch(`${this.baseUrl}/api/logs?name=${encodeURIComponent(name)}`, {
      headers: { Accept: 'text/plain' },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch logs for ${name}: ${response.statusText}`);
    }
    
    return response.text();
  }

  private parseResources(data: any): TiltResource[] {
    // Tilt API returns a view object with uiResources
    const uiResources = data?.uiSession?.status?.view?.uiResources || [];
    
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
