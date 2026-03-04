import { useState, useCallback } from 'react';
import { useAsync } from 'react-use';
import {
  Content,
  ContentHeader,
  Header,
  HeaderLabel,
  Page,
  SupportButton,
  Table,
  TableColumn,
  StatusOK,
  StatusPending,
  StatusError,
  StatusAborted,
} from '@backstage/core-components';
import { useApi } from '@backstage/core-plugin-api';
import { tiltApiRef, TiltResource } from '../api';
import {
  Button,
  Chip,
  IconButton,
  Tooltip,
  makeStyles,
} from '@material-ui/core';
import RefreshIcon from '@material-ui/icons/Refresh';
import PlayArrowIcon from '@material-ui/icons/PlayArrow';
import OpenInNewIcon from '@material-ui/icons/OpenInNew';
import PowerSettingsNewIcon from '@material-ui/icons/PowerSettingsNew';

const useStyles = makeStyles(theme => ({
  chip: {
    margin: theme.spacing(0.5),
  },
  actionButton: {
    marginRight: theme.spacing(1),
  },
}));

const StatusIcon = ({ status }: { status: string }) => {
  switch (status) {
    case 'ok':
      return <StatusOK />;
    case 'pending':
      return <StatusPending />;
    case 'error':
      return <StatusError />;
    default:
      return <StatusAborted />;
  }
};

export const TiltPage = () => {
  const classes = useStyles();
  const tiltApi = useApi(tiltApiRef);
  const [refreshKey, setRefreshKey] = useState(0);
  const retry = useCallback(() => setRefreshKey(k => k + 1), []);
  
  const { value: resources, loading, error } = useAsync(
    () => tiltApi.getResources(),
    [tiltApi, refreshKey],
  );

  const handleTrigger = async (name: string) => {
    await tiltApi.triggerResource(name);
    retry();
  };

  const handleToggle = async (resource: TiltResource) => {
    await tiltApi.enableResource(resource.name, resource.disabled);
    retry();
  };

  const totalResources = resources?.length || 0;
  const runningCount = resources?.filter(r => r.runtimeStatus === 'ok').length || 0;
  const errorCount = resources?.filter(r => r.runtimeStatus === 'error').length || 0;

  const columns: TableColumn<TiltResource>[] = [
    {
      title: 'Name',
      field: 'name',
      highlight: true,
    },
    {
      title: 'Type',
      field: 'type',
    },
    {
      title: 'Runtime',
      render: (row) => <StatusIcon status={row.runtimeStatus} />,
    },
    {
      title: 'Build',
      render: (row) => <StatusIcon status={row.updateStatus} />,
    },
    {
      title: 'Labels',
      render: (row) => (
        <>
          {row.labels.map(label => (
            <Chip
              key={label}
              label={label}
              size="small"
              className={classes.chip}
            />
          ))}
        </>
      ),
    },
    {
      title: 'Actions',
      render: (row) => (
        <>
          <Tooltip title="Trigger rebuild">
            <IconButton
              size="small"
              onClick={() => handleTrigger(row.name)}
              className={classes.actionButton}
            >
              <PlayArrowIcon />
            </IconButton>
          </Tooltip>
          <Tooltip title={row.disabled ? 'Enable' : 'Disable'}>
            <IconButton
              size="small"
              onClick={() => handleToggle(row)}
              className={classes.actionButton}
              color={row.disabled ? 'default' : 'primary'}
            >
              <PowerSettingsNewIcon />
            </IconButton>
          </Tooltip>
          {row.endpointLinks.map((link, i) => (
            <Tooltip key={i} title={link.name || link.url}>
              <IconButton
                size="small"
                href={link.url}
                target="_blank"
                className={classes.actionButton}
              >
                <OpenInNewIcon />
              </IconButton>
            </Tooltip>
          ))}
        </>
      ),
    },
  ];

  return (
    <Page themeId="tool">
      <Header title="Tilt Resources" subtitle="Local Development Environment">
        <HeaderLabel label="Running" value={loading ? '...' : `${runningCount} / ${totalResources}`} />
        {errorCount > 0 && <HeaderLabel label="Errors" value={`${errorCount}`} />}
        <HeaderLabel label="Total" value={loading ? 'Loading...' : `${totalResources} resources`} />
      </Header>
      <Content>
        <ContentHeader title="Resources">
          <Button
            variant="contained"
            color="primary"
            startIcon={<RefreshIcon />}
            onClick={retry}
          >
            Refresh
          </Button>
          <SupportButton>
            Tilt manages your local Kubernetes development environment.
          </SupportButton>
        </ContentHeader>
        <Table
          title="Tilt Resources"
          options={{ search: true, paging: true, pageSize: 20 }}
          columns={columns}
          data={resources || []}
          isLoading={loading}
          emptyContent={
            error ? (
              <div>Error loading resources: {error.message}</div>
            ) : (
              <div>No resources found. Is Tilt running?</div>
            )
          }
        />
      </Content>
    </Page>
  );
};
