::tf_objective_resource <- Entities.FindByClassname(null, "tf_objective_resource");

if (tf_objective_resource == null || !tf_objective_resource.IsValid()) {
    error(self + " -- tf_objective_resource not found\n");
    return;
}

/**
 * Get the MvM wave number
 * @return {integer} Wave number
 */
::GetMvMWave <- function() {
    return NetProps.GetPropInt(tf_objective_resource, "m_nMannVsMachineWaveCount");
}

/**
 * Get the MvM pop file name
 * @return {string} MvM pop file name
 */
::GetMvMPopFile <- function() {
    return NetProps.GetPropString(tf_objective_resource, "m_iszMvMPopfileName");
}