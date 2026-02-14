import React from 'react';
import { useEntity } from '@backstage/plugin-catalog-react';
import { TiltResourceCard } from './TiltResourceCard';
import { Typography, Box } from '@material-ui/core';

const TILT_RESOURCE_ANNOTATION = 'tilt.dev/resource';

export const EntityTiltContent = () => {
  const { entity } = useEntity();
  
  const tiltResourceName = entity.metadata.annotations?.[TILT_RESOURCE_ANNOTATION];
  
  if (!tiltResourceName) {
    return (
      <Box p={2}>
        <Typography variant="body1" color="textSecondary">
          This component is not linked to a Tilt resource.
        </Typography>
        <Typography variant="body2" color="textSecondary">
          Add the <code>tilt.dev/resource</code> annotation to link it.
        </Typography>
      </Box>
    );
  }
  
  return <TiltResourceCard resourceName={tiltResourceName} />;
};
