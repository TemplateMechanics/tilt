import {
  createPlugin,
  createApiFactory,
  configApiRef,
  createRoutableExtension,
  createComponentExtension,
} from '@backstage/core-plugin-api';
import { tiltApiRef, TiltClient } from './api';
import { rootRouteRef } from './routes';

export const tiltPlugin = createPlugin({
  id: 'tilt',
  apis: [
    createApiFactory({
      api: tiltApiRef,
      deps: { configApi: configApiRef },
      factory: ({ configApi }) => new TiltClient({ configApi }),
    }),
  ],
  routes: {
    root: rootRouteRef,
  },
});

export const TiltPage = tiltPlugin.provide(
  createRoutableExtension({
    name: 'TiltPage',
    component: () =>
      import('./components/TiltPage').then(m => m.TiltPage),
    mountPoint: rootRouteRef,
  }),
);

export const TiltResourceCard = tiltPlugin.provide(
  createComponentExtension({
    name: 'TiltResourceCard',
    component: {
      lazy: () =>
        import('./components/TiltResourceCard').then(m => m.TiltResourceCard),
    },
  }),
);

export const EntityTiltContent = tiltPlugin.provide(
  createComponentExtension({
    name: 'EntityTiltContent',
    component: {
      lazy: () =>
        import('./components/EntityTiltContent').then(m => m.EntityTiltContent),
    },
  }),
);
