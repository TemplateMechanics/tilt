# Third-party notices

This repository is licensed under the [MIT License](LICENSE), except for the
third-party material listed below. That material keeps its own licence, and its
notices are reproduced or referenced here.

## Kyverno policies

- **Path:** `helm/kyverno-policies/*.yaml` (12 policies)
- **Source:** <https://github.com/kyverno/policies/tree/release-1.9/pod-security/baseline>
- **Licence:** Apache License 2.0, <https://www.apache.org/licenses/LICENSE-2.0>.
  Copyright The Kyverno Authors.
- **Modified:** yes. Each file carries a change notice, and
  [`helm/kyverno-policies/README.md`](helm/kyverno-policies/README.md) lists the changes.

## Microsoft SQL Server sample Helm chart

- **Path:** `helm/mssql/`
- **Source:** <https://github.com/microsoft/mssql-docker/tree/master/linux/sample-helm-chart>
- **Licence:** MIT. `Chart.yaml` differs only by an added source comment;
  `_helpers.tpl`, `mssqlconfig.yaml`, `secret.yaml` and `service.yaml` are
  unchanged. Adapted: `values.yaml` (SQL Server 2022 Express image, replica,
  path and storage settings), `deployment.yaml` (readiness and liveness probes,
  named ports) and `pvc.yaml` (the Azure `StorageClass` object removed in favour
  of an optional `storageClassName`). The upstream notice:

```text
Copyright(c) 2016 Microsoft Corporation
All rights reserved.

MIT License
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files(the "Software"), 
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and / or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions :

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
IN THE SOFTWARE.
```

## Backstage application scaffold

- **Path:** `backstage/app/` (generated with Backstage's `create-app`;
  `backstage/app/backstage.json` records version 1.48.0)
- **Source:** <https://github.com/backstage/backstage>
- **Licence:** Apache License 2.0, <https://www.apache.org/licenses/LICENSE-2.0>.
  Copyright The Backstage Authors.
- **Upstream NOTICE**, reproduced as Apache-2.0 section 4(d) asks:

```text
Backstage
Copyright 2020 The Backstage Authors

Portions of this software were developed by third-party software vendors:

- Tech Radar Plugin (https://opensource.zalando.com/tech-radar/), Copyright (c) 2017 Zalando SE
- [OpenAPI Generator Templates](./packages/repo-tools/templates), Copyright 2018 OpenAPI-Generator Contributors (https://openapi-generator.tech) Copyright 2018 SmartBear Software
```

- Code generated from Backstage's templates remains under Apache-2.0, including the
  two files that carry the Backstage licence header:
  `backstage/app/packages/app/e2e-tests/app.test.ts` and
  `backstage/app/playwright.config.ts`. Code written for this repository, such as
  the Tilt plugin's own components, is under MIT.

## Yarn

- **Path:** `backstage/app/.yarn/releases/yarn-4.4.1.cjs` (vendored release binary)
- **Source:** <https://github.com/yarnpkg/berry>
- **Licence:** BSD 2-Clause, reproduced below as its clause 2 requires. The bundle
  also contains code from other packages, each under its own licence.

```text
BSD 2-Clause License

Copyright (c) 2016-present, Yarn Contributors.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## Traefik Helm chart values

- **Path:** `archive/traefik/traefik-values.yaml` (archived; not applied by the Tiltfile)
- **Source:** <https://github.com/traefik/traefik-helm-chart/blob/v34.1.0/traefik/values.yaml>
  (closest upstream release by diff)
- **Licence:** Apache License 2.0, <https://www.apache.org/licenses/LICENSE-2.0>.
  Copyright 2020 Containous; copyright 2020 Traefik Labs.
- **Modified:** yes, and the file carries a change notice. Changes: the image tag
  (`3.6.5`), `allowCrossNamespace: true`, metrics labels enabled, a ServiceMonitor
  note, and commented-out `globalArguments` and redirections.
