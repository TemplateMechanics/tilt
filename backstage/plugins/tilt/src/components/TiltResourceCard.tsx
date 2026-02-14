import React from 'react';
import { useAsync } from 'react-use';
import {
  InfoCard,
  StatusOK,
  StatusPending,
  StatusError,
  StatusAborted,
} from '@backstage/core-components';
import { useApi } from '@backstage/core-plugin-api';
import { tiltApiRef, TiltResource } from '../api';
import {
  Button,
  Grid,
  Typography,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  makeStyles,
} from '@material-ui/core';
import PlayArrowIcon from '@material-ui/icons/PlayArrow';
import OpenInNewIcon from '@material-ui/icons/OpenInNew';
import CheckCircleIcon from '@material-ui/icons/CheckCircle';
import ErrorIcon from '@material-ui/icons/Error';
import HourglassEmptyIcon from '@material-ui/icons/HourglassEmpty';

const useStyles = makeStyles(theme => ({
  statusIcon: {
    minWidth: 32,
  },
  actionButton: {
    marginRight: theme.spacing(1),
  },
}));

interface TiltResourceCardProps {
  resourceName: string;
}

export const TiltResourceCard = ({ resourceName }: TiltResourceCardProps) => {
  const classes = useStyles();
  const tiltApi = useApi(tiltApiRef);
  
  const { value: resource, loading, error, retry } = useAsync(
    () => tiltApi.getResource(resourceName),
    [tiltApi, resourceName],
  );

  const handleTrigger = async () => {
    await tiltApi.triggerResource(resourceName);
    retry();
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'ok':
        return <CheckCircleIcon style={{ color: 'green' }} />;
      case 'pending':
        return <HourglassEmptyIcon style={{ color: 'orange' }} />;
      case 'error':
        return <ErrorIcon style={{ color: 'red' }} />;
      default:
        return <HourglassEmptyIcon />;
    }
  };

  if (loading) {
    return (
      <InfoCard title={`Tilt: ${resourceName}`}>
        <Typography>Loading...</Typography>
      </InfoCard>
    );
  }

  if (error || !resource) {
    return (
      <InfoCard title={`Tilt: ${resourceName}`}>
        <Typography color="error">
          {error?.message || 'Resource not found. Is Tilt running?'}
        </Typography>
      </InfoCard>
    );
  }

  return (
    <InfoCard
      title={`Tilt: ${resource.name}`}
      subheader={resource.type}
      action={
        <>
          <Button
            variant="outlined"
            size="small"
            startIcon={<PlayArrowIcon />}
            onClick={handleTrigger}
            className={classes.actionButton}
          >
            Trigger
          </Button>
          {resource.endpointLinks.map((link, i) => (
            <Button
              key={i}
              variant="outlined"
              size="small"
              startIcon={<OpenInNewIcon />}
              href={link.url}
              target="_blank"
              className={classes.actionButton}
            >
              {link.name || 'Open'}
            </Button>
          ))}
        </>
      }
    >
      <Grid container spacing={2}>
        <Grid item xs={6}>
          <List dense>
            <ListItem>
              <ListItemIcon className={classes.statusIcon}>
                {getStatusIcon(resource.runtimeStatus)}
              </ListItemIcon>
              <ListItemText primary="Runtime" secondary={resource.runtimeStatus} />
            </ListItem>
            <ListItem>
              <ListItemIcon className={classes.statusIcon}>
                {getStatusIcon(resource.updateStatus)}
              </ListItemIcon>
              <ListItemText primary="Build" secondary={resource.updateStatus} />
            </ListItem>
          </List>
        </Grid>
        <Grid item xs={6}>
          {resource.buildHistory.length > 0 && (
            <Typography variant="body2" color="textSecondary">
              Last build: {new Date(resource.buildHistory[0].finishTime || resource.buildHistory[0].startTime).toLocaleString()}
              {resource.buildHistory[0].error && (
                <Typography color="error" variant="caption" display="block">
                  Error: {resource.buildHistory[0].error}
                </Typography>
              )}
            </Typography>
          )}
        </Grid>
      </Grid>
    </InfoCard>
  );
};
