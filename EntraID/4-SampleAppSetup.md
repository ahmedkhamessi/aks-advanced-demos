# Create and test a new console app
dotnet new console -n keyvault-console-app
cd keyvault-console-app
dotnet run

# Add the Key Vault and Azure Identity Packages
dotnet add package Azure.Security.KeyVault.Secrets
dotnet add package Azure.Identity