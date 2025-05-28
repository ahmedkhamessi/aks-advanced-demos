# Variables - update these as needed
RESOURCE_GROUP="<RESOURCE_GROUP>"
LOCATION="<LOCATION>"
IDENTITY_NAME="<IDENTITY_NAME>"

# GitHub repo details for federated credential
GITHUB_ORG="<GITHUB_ORG>"
GITHUB_REPO="<GITHUB_REPO>"
GITHUB_ENV="<GITHUB_ENV>" # e.g., 'Development' or 'Production'

# Create resource group if it doesn't exist
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create the User-Assigned Managed Identity
az identity create --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --location $LOCATION

# Get the identity's resource ID and principalId
IDENTITY_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'id' -o tsv)
IDENTITY_PRINCIPAL_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'principalId' -o tsv)

# Get the current subscription ID
SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)

# Assign Contributor role to the identity at the subscription scope
az role assignment create --assignee $IDENTITY_PRINCIPAL_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID"

# Add federated credential for GitHub Actions
az identity federated-credential create \
  --name github-actions-federated-cred \
  --identity-name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:${GITHUB_ENV}" \
  --audiences "api://AzureADTokenExchange"