# Project Generator Script

This script automates the creation of a .NET Clean Architecture project structure with all necessary dependencies and configurations.

## Usage

```bash
./create-project.sh <ProjectName> <NetVersion>
```

### Parameters

- **ProjectName**: The name of your project (e.g., `MyProject`, `BillpaymentsMiddleware`)
- **NetVersion**: The .NET version to use (e.g., `8.0`, `9.0`, `10.0`)

### Examples

```bash
# Create a project with .NET 10.0
./create-project.sh MyProject 10.0

# Create a project with .NET 8.0
./create-project.sh ApiService 8.0

# Create a project with .NET 9.0
./create-project.sh PaymentGateway 9.0
```

## What Gets Created

The script creates a complete Clean Architecture solution with:

### Project Structure

```
<ProjectName>/
├── <ProjectName>.slnx              # Solution file
├── global.json                      # SDK version configuration
├── docker-compose.yml              # Docker services configuration
├── src/
│   ├── <ProjectName>.Domain/       # Domain layer
│   │   ├── Entity.cs
│   │   ├── DomainException.cs
│   │   └── IDomainEvent.cs
│   ├── <ProjectName>.Application/ # Application layer
│   ├── <ProjectName>.Infrastructure/ # Infrastructure layer
│   └── <ProjectName>.WebApi/      # Web API layer
│       ├── Program.cs
│       ├── appsettings.json
│       ├── appsettings.Development.json
│       └── Properties/launchSettings.json
└── tests/
    ├── <ProjectName>.Application.UnitTests/
    ├── <ProjectName>.Domain.UnitTests/
    └── <ProjectName>.Infrastructure.UnitTests/
```

### Included Packages

**Domain Layer:**
- Base classes only (no external dependencies)

**Application Layer:**
- MassTransit 8.2.3
- FluentValidation 11.10.0
- Newtonsoft.Json 13.0.3

**Infrastructure Layer:**
- FluentValidation.AspNetCore 11.3.0
- MassTransit.RabbitMQ 8.2.4-develop.1867
- Microsoft.AspNetCore.Authentication.JwtBearer (version matches .NET version)
- Microsoft.AspNetCore.OpenApi (version matches .NET version)
- Microsoft.Extensions.Caching.StackExchangeRedis (version matches .NET version)
- Npgsql.EntityFrameworkCore.PostgreSQL (version matches .NET version)
- OpenTelemetry packages
- Swashbuckle.AspNetCore packages (version matches .NET version)
- System.Linq.Dynamic.Core 1.4.9

**WebApi Layer:**
- Microsoft.AspNetCore.OpenApi (version matches .NET version)
- Microsoft.EntityFrameworkCore.Design (version matches .NET version)
- Npgsql.EntityFrameworkCore.PostgreSQL (version matches .NET version)
- Scalar.AspNetCore 1.2.45

**Test Projects:**
- xunit 2.9.3
- Microsoft.NET.Test.Sdk 17.14.1
- coverlet.collector 6.0.4

### Features

- ✅ Clean Architecture structure
- ✅ All namespaces automatically set to match project name
- ✅ All project references properly configured
- ✅ Swagger/OpenAPI configured
- ✅ Docker Compose setup for development services
- ✅ Unit test projects ready to use
- ✅ Configuration files with sensible defaults
- ✅ Automatic package restore and build verification

## Requirements

- .NET SDK (version specified in NetVersion parameter)
- Bash shell (macOS/Linux) or Git Bash (Windows)

## Notes

- The script will automatically restore packages and build the solution after creation
- Package versions for Microsoft.* packages will match the specified .NET version
- The database name in `appsettings.json` will be set to the project name
- The telemetry name will be set to the project name

## Troubleshooting

If you encounter issues:

1. **Permission denied**: Make sure the script is executable:
   ```bash
   chmod +x create-project.sh
   ```

2. **.NET version not found**: Ensure you have the specified .NET SDK version installed:
   ```bash
   dotnet --list-sdks
   ```

3. **Package restore fails**: Check your internet connection and NuGet feed configuration

4. **Build fails**: Verify that all required .NET SDK versions are installed
