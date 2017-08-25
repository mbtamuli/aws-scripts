application_name =            "wordpress"
application_desc =            "wordpress test application"

echo -e "[\e[0;34mNOTICE\e[0m] Creating application $application_name"
if [[ -n "${application_name// }" ]]; then
  # If application name is declared in the config, check if it already exists.
  $(aws elasticbeanstalk describe-applications \
             --application-names "$application_name" \
             --output text > /dev/null 2>&1)
  status="$?"
  if [[ "$status" -ne 0 ]]; then
    # It doesn't exist in AWS. So create it.
    aws elasticbeanstalk create-application --application-name "$application_name" --description "$application_desc"
  fi
fi
