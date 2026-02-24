import { useState, useCallback } from 'react';
import { useAsync } from 'react-use';
import {
  Content,
  ContentHeader,
  Header,
  HeaderLabel,
  Page,
  SupportButton,
} from '@backstage/core-components';
import { useApi } from '@backstage/core-plugin-api';
import { tiltApiRef, InfraService } from '../api';
import {
  Box,
  Button,
  Card,
  CardContent,
  CardHeader,
  Chip,
  Collapse,
  Grid,
  IconButton,
  LinearProgress,
  Link,
  Paper,
  Snackbar,
  Switch,
  Tooltip,
  Typography,
  makeStyles,
} from '@material-ui/core';
import { Alert } from '@material-ui/lab';
import RefreshIcon from '@material-ui/icons/Refresh';
import OpenInNewIcon from '@material-ui/icons/OpenInNew';
import PlayArrowIcon from '@material-ui/icons/PlayArrow';
import ExpandMoreIcon from '@material-ui/icons/ExpandMore';
import ExpandLessIcon from '@material-ui/icons/ExpandLess';
import CheckCircleIcon from '@material-ui/icons/CheckCircle';
import WarningIcon from '@material-ui/icons/Warning';
import StorageIcon from '@material-ui/icons/Storage';
import SecurityIcon from '@material-ui/icons/Security';
import CloudIcon from '@material-ui/icons/Cloud';
import BuildIcon from '@material-ui/icons/Build';
import CodeIcon from '@material-ui/icons/Code';
import MemoryIcon from '@material-ui/icons/Memory';
import EmailIcon from '@material-ui/icons/Email';
import SportsEsportsIcon from '@material-ui/icons/SportsEsports';
import SettingsIcon from '@material-ui/icons/Settings';
import DashboardIcon from '@material-ui/icons/Dashboard';
import VpnKeyIcon from '@material-ui/icons/VpnKey';

const useStyles = makeStyles(theme => ({
  root: {
    padding: theme.spacing(2),
  },
  categoryCard: {
    marginBottom: theme.spacing(2),
  },
  categoryHeader: {
    cursor: 'pointer',
    '&:hover': {
      backgroundColor: theme.palette.action.hover,
    },
  },
  categoryHeaderContent: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    width: '100%',
  },
  categoryTitle: {
    display: 'flex',
    alignItems: 'center',
    gap: theme.spacing(1),
  },
  categoryStats: {
    display: 'flex',
    alignItems: 'center',
    gap: theme.spacing(1),
  },
  serviceCard: {
    border: `1px solid ${theme.palette.divider}`,
    borderRadius: theme.shape.borderRadius,
    padding: theme.spacing(2),
    transition: 'all 0.2s ease',
    '&:hover': {
      boxShadow: theme.shadows[2],
      borderColor: theme.palette.primary.light,
    },
  },
  serviceCardEnabled: {
    borderLeft: `4px solid ${theme.palette.success.main}`,
  },
  serviceCardDisabled: {
    borderLeft: `4px solid ${theme.palette.grey[400]}`,
    opacity: 0.85,
  },
  serviceHeader: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: theme.spacing(1),
  },
  serviceName: {
    fontWeight: 600,
    fontSize: '1rem',
  },
  serviceDescription: {
    color: theme.palette.text.secondary,
    fontSize: '0.85rem',
    marginBottom: theme.spacing(1),
  },
  serviceActions: {
    display: 'flex',
    alignItems: 'center',
    gap: theme.spacing(0.5),
    marginTop: theme.spacing(1),
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: '50%',
    display: 'inline-block',
    marginRight: theme.spacing(0.5),
  },
  statusOk: { backgroundColor: theme.palette.success.main },
  statusPending: { backgroundColor: theme.palette.warning.main },
  statusError: { backgroundColor: theme.palette.error.main },
  statusUnknown: { backgroundColor: theme.palette.grey[400] },
  testedBadge: {
    fontSize: '0.7rem',
    height: 20,
  },
  summaryBar: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: theme.spacing(2),
    marginBottom: theme.spacing(2),
    backgroundColor: theme.palette.background.default,
    borderRadius: theme.shape.borderRadius,
  },
  summaryStats: {
    display: 'flex',
    gap: theme.spacing(3),
  },
  summaryStatValue: {
    fontWeight: 700,
    fontSize: '1.2rem',
  },
  summaryStatLabel: {
    fontSize: '0.75rem',
    color: theme.palette.text.secondary,
    textTransform: 'uppercase',
  },
  groupTag: {
    fontSize: '0.65rem',
    height: 18,
  },
}));

/** Map category names to icons */
const categoryIcon: Record<string, React.ReactElement> = {
  'Infrastructure': <SettingsIcon />,
  'Developer Portal': <DashboardIcon />,
  'Security & Policy': <SecurityIcon />,
  'Databases': <StorageIcon />,
  'Identity & Workflow': <VpnKeyIcon />,
  'AI/ML': <MemoryIcon />,
  'CI/CD': <BuildIcon />,
  'Cloud Emulators': <CloudIcon />,
  'Dev Tools': <EmailIcon />,
  'Demo Apps': <SportsEsportsIcon />,
  'Experimental': <CodeIcon />,
};

/** Map group names to display labels */
const groupLabel: Record<string, string> = {
  crossplane_apps: 'Crossplane',
  flux_apps: 'Flux',
  raw_apps: 'Raw',
};

const groupColor: Record<string, 'primary' | 'secondary' | 'default'> = {
  crossplane_apps: 'primary',
  flux_apps: 'secondary',
  raw_apps: 'default',
};

export const InfrastructureDashboard = () => {
  const classes = useStyles();
  const tiltApi = useApi(tiltApiRef);

  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set(['Databases', 'AI/ML', 'Infrastructure']));
  const [pendingToggles, setPendingToggles] = useState<Set<string>>(new Set());
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' | 'info' }>({
    open: false, message: '', severity: 'info',
  });

  const [refreshKey, setRefreshKey] = useState(0);
  const retry = useCallback(() => setRefreshKey(k => k + 1), []);

  const { value: categories, loading, error } = useAsync(
    () => tiltApi.getInfraCategories(),
    [tiltApi, refreshKey],
  );

  const toggleCategory = useCallback((name: string) => {
    setExpandedCategories(prev => {
      const next = new Set(prev);
      if (next.has(name)) {
        next.delete(name);
      } else {
        next.add(name);
      }
      return next;
    });
  }, []);

  const handleToggleService = useCallback(async (service: InfraService) => {
    const key = `${service.group}.${service.name}`;
    setPendingToggles(prev => new Set(prev).add(key));

    try {
      await tiltApi.setServiceEnabled(service.group, service.name, !service.enabled);
      setSnackbar({
        open: true,
        message: `${service.name} ${!service.enabled ? 'enabled' : 'disabled'}. Tilt will reload automatically.`,
        severity: 'success',
      });
      // Refresh data after a short delay to let config-server write
      setTimeout(() => retry(), 500);
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: `Failed to toggle ${service.name}: ${err.message}`,
        severity: 'error',
      });
    } finally {
      setPendingToggles(prev => {
        const next = new Set(prev);
        next.delete(key);
        return next;
      });
    }
  }, [tiltApi, retry]);

  const handleTrigger = useCallback(async (service: InfraService) => {
    try {
      await tiltApi.triggerResource(service.name);
      setSnackbar({ open: true, message: `Triggered rebuild for ${service.name}`, severity: 'info' });
      setTimeout(() => retry(), 1000);
    } catch (err: any) {
      setSnackbar({ open: true, message: `Failed to trigger ${service.name}: ${err.message}`, severity: 'error' });
    }
  }, [tiltApi, retry]);

  // Compute summary stats
  const allServices = categories?.flatMap(c => c.services) || [];
  const enabledCount = allServices.filter(s => s.enabled).length;
  const runningCount = allServices.filter(s => s.runtimeStatus === 'ok').length;
  const errorCount = allServices.filter(s => s.runtimeStatus === 'error' || s.updateStatus === 'error').length;
  const totalCount = allServices.length;

  const getStatusDotClass = (status?: string) => {
    switch (status) {
      case 'ok': return classes.statusOk;
      case 'pending': return classes.statusPending;
      case 'error': return classes.statusError;
      default: return classes.statusUnknown;
    }
  };

  return (
    <Page themeId="tool">
      <Header title="Infrastructure Control" subtitle="Manage your local development services">
        <HeaderLabel label="Total" value={`${totalCount} services`} />
        <HeaderLabel label="Enabled" value={`${enabledCount}`} />
        <HeaderLabel label="Running" value={`${runningCount}`} />
      </Header>
      <Content>
        <ContentHeader title="Service Management">
          <Button
            variant="contained"
            color="primary"
            startIcon={<RefreshIcon />}
            onClick={retry}
            disabled={loading}
          >
            Refresh
          </Button>
          <SupportButton>
            Toggle services on/off to control your local Kubernetes infrastructure.
            Changes are persisted to tilt-config.json and Tilt reloads automatically.
          </SupportButton>
        </ContentHeader>

        {loading && <LinearProgress />}

        {error && (
          <Alert severity="error" style={{ marginBottom: 16 }}>
            Failed to load infrastructure config: {error.message}.
            Make sure Tilt is running and the config server is accessible.
          </Alert>
        )}

        {/* Summary Bar */}
        {categories && (
          <Paper className={classes.summaryBar} elevation={0}>
            <div className={classes.summaryStats}>
              <div>
                <Typography className={classes.summaryStatValue}>{enabledCount}</Typography>
                <Typography className={classes.summaryStatLabel}>Enabled</Typography>
              </div>
              <div>
                <Typography className={classes.summaryStatValue} style={{ color: runningCount > 0 ? '#4caf50' : undefined }}>
                  {runningCount}
                </Typography>
                <Typography className={classes.summaryStatLabel}>Running</Typography>
              </div>
              <div>
                <Typography className={classes.summaryStatValue} style={{ color: errorCount > 0 ? '#f44336' : undefined }}>
                  {errorCount}
                </Typography>
                <Typography className={classes.summaryStatLabel}>Errors</Typography>
              </div>
              <div>
                <Typography className={classes.summaryStatValue}>{totalCount}</Typography>
                <Typography className={classes.summaryStatLabel}>Total</Typography>
              </div>
            </div>
            <Button
              variant="outlined"
              size="small"
              href="http://localhost:10350"
              target="_blank"
              startIcon={<OpenInNewIcon />}
            >
              Open Tilt UI
            </Button>
          </Paper>
        )}

        {/* Category cards */}
        {categories?.map(category => {
          const isExpanded = expandedCategories.has(category.name);
          const catEnabled = category.services.filter(s => s.enabled).length;
          const catTotal = category.services.length;

          return (
            <Card key={category.name} className={classes.categoryCard} variant="outlined">
              <CardHeader
                className={classes.categoryHeader}
                onClick={() => toggleCategory(category.name)}
                avatar={categoryIcon[category.name] || <SettingsIcon />}
                title={
                  <div className={classes.categoryHeaderContent}>
                    <div className={classes.categoryTitle}>
                      <Typography variant="h6">{category.name}</Typography>
                      <Chip
                        label={`${catEnabled}/${catTotal} enabled`}
                        size="small"
                        color={catEnabled > 0 ? 'primary' : 'default'}
                        variant={catEnabled > 0 ? 'default' : 'outlined'}
                      />
                    </div>
                    <div className={classes.categoryStats}>
                      {category.services.some(s => s.runtimeStatus === 'error') && (
                        <WarningIcon style={{ color: '#f44336', fontSize: 20 }} />
                      )}
                      {category.services.some(s => s.runtimeStatus === 'ok') && (
                        <CheckCircleIcon style={{ color: '#4caf50', fontSize: 20 }} />
                      )}
                      {isExpanded ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                    </div>
                  </div>
                }
              />
              <Collapse in={isExpanded}>
                <CardContent>
                  <Grid container spacing={2}>
                    {category.services.map(service => {
                      const toggleKey = `${service.group}.${service.name}`;
                      const isPending = pendingToggles.has(toggleKey);

                      return (
                        <Grid item xs={12} sm={6} md={4} key={toggleKey}>
                          <div className={`${classes.serviceCard} ${service.enabled ? classes.serviceCardEnabled : classes.serviceCardDisabled}`}>
                            <div className={classes.serviceHeader}>
                              <div>
                                <Typography className={classes.serviceName}>
                                  {service.name}
                                </Typography>
                                <Chip
                                  label={groupLabel[service.group]}
                                  size="small"
                                  color={groupColor[service.group]}
                                  className={classes.groupTag}
                                  variant="outlined"
                                />
                              </div>
                              <Tooltip title={service.enabled ? 'Disable service' : 'Enable service'}>
                                <Switch
                                  checked={service.enabled}
                                  onChange={() => handleToggleService(service)}
                                  disabled={isPending}
                                  color="primary"
                                  size="small"
                                />
                              </Tooltip>
                            </div>

                            <Typography className={classes.serviceDescription}>
                              {service.description}
                            </Typography>

                            {/* Status indicators */}
                            {service.enabled && service.runtimeStatus && (
                              <Box display="flex" alignItems="center" style={{ gap: 8 }} mb={0.5}>
                                <span className={`${classes.statusDot} ${getStatusDotClass(service.runtimeStatus)}`} />
                                <Typography variant="caption" color="textSecondary">
                                  Runtime: {service.runtimeStatus}
                                </Typography>
                                {service.updateStatus && service.updateStatus !== 'not_applicable' && (
                                  <>
                                    <span className={`${classes.statusDot} ${getStatusDotClass(service.updateStatus)}`} />
                                    <Typography variant="caption" color="textSecondary">
                                      Build: {service.updateStatus}
                                    </Typography>
                                  </>
                                )}
                              </Box>
                            )}

                            {/* Actions */}
                            <div className={classes.serviceActions}>
                              {service.tested && (
                                <Chip
                                  icon={<CheckCircleIcon style={{ fontSize: 14 }} />}
                                  label="tested"
                                  size="small"
                                  className={classes.testedBadge}
                                  variant="outlined"
                                  color="primary"
                                />
                              )}
                              {service.enabled && (
                                <Tooltip title="Trigger rebuild">
                                  <IconButton size="small" onClick={() => handleTrigger(service)}>
                                    <PlayArrowIcon fontSize="small" />
                                  </IconButton>
                                </Tooltip>
                              )}
                              {service.links?.map((link, i) => (
                                <Tooltip key={i} title={link.name || link.url}>
                                  <IconButton
                                    size="small"
                                    href={link.url}
                                    target="_blank"
                                    component="a"
                                  >
                                    <OpenInNewIcon fontSize="small" />
                                  </IconButton>
                                </Tooltip>
                              ))}
                              {service.enabled && (
                                <Link
                                  href={`https://${service.name}.localhost`}
                                  target="_blank"
                                  variant="caption"
                                  color="textSecondary"
                                >
                                  {service.name}.localhost
                                </Link>
                              )}
                            </div>
                          </div>
                        </Grid>
                      );
                    })}
                  </Grid>
                </CardContent>
              </Collapse>
            </Card>
          );
        })}

        <Snackbar
          open={snackbar.open}
          autoHideDuration={4000}
          onClose={() => setSnackbar(prev => ({ ...prev, open: false }))}
        >
          <Alert
            onClose={() => setSnackbar(prev => ({ ...prev, open: false }))}
            severity={snackbar.severity}
          >
            {snackbar.message}
          </Alert>
        </Snackbar>
      </Content>
    </Page>
  );
};
