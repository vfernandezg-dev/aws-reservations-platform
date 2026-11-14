export interface TaskMetadata {
  availabilityZone: string | undefined;
  taskArn: string | undefined;
}

interface EcsTaskMetadataResponse {
  AvailabilityZone?: string;
  TaskARN?: string;
}

/**
 * Reads the ECS task metadata endpoint (v4). Outside ECS the variable is not
 * set and the function returns empty values instead of failing.
 */
export async function fetchTaskMetadata(
  env: NodeJS.ProcessEnv = process.env,
): Promise<TaskMetadata> {
  const baseUrl = env.ECS_CONTAINER_METADATA_URI_V4;
  if (!baseUrl) return { availabilityZone: undefined, taskArn: undefined };

  try {
    const response = await fetch(`${baseUrl}/task`, { signal: AbortSignal.timeout(1_000) });
    const body = (await response.json()) as EcsTaskMetadataResponse;
    return { availabilityZone: body.AvailabilityZone, taskArn: body.TaskARN };
  } catch {
    return { availabilityZone: undefined, taskArn: undefined };
  }
}
