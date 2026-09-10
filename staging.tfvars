environment           = "staging"
region                = "eu-west-1" # Cheaper ( for EC2 at least )
log_retention_in_days = 60
app_log_level         = "INFO"
system_log_level      = "WARN"
github_repo_condition = "repo:IAmAStealer@24506305/home_task_aws@1360249375:ref:refs/heads/main"
state_bucket          = "3a43faa4-955a-4c3d-9579-af96f65a9932"
