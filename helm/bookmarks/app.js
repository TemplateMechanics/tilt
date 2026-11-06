"use strict";
// Keep *.localhost links on the same port when using kind/cluster-alt-ports.yaml.
// This page never fetches any URL; navigation is initiated only by learners.
for (const link of document.querySelectorAll("a[data-local-host]")) {
  const host = link.dataset.localHost;
  const path = link.dataset.localPath || "/";
  if (!/^[a-z][a-z0-9-]*$/.test(host) || !path.startsWith("/")) continue;
  const gatewayPort = window.location.port ? ":" + window.location.port : "";
  link.href = "https://" + host + ".localhost" + gatewayPort + path;
}
