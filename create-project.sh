#!/bin/bash

# Script to create a new .NET project with Clean Architecture structure
# Usage: ./create-project.sh <ProjectName> <NetVersion>
# Example: ./create-project.sh MyProject 10.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if project name and .NET version are provided
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    echo "Usage: $0 <ProjectName> <NetVersion>"
    echo "Example: $0 MyProject 10.0"
    exit 1
fi

PROJECT_NAME=$1
NET_VERSION=$2

# Validate .NET version format (should be like 8.0, 9.0, 10.0, etc.)
if ! [[ "$NET_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid .NET version format. Use format like 8.0, 9.0, 10.0${NC}"
    exit 1
fi

# Convert .NET version to target framework (e.g., 10.0 -> net10.0)
TARGET_FRAMEWORK="net${NET_VERSION}"

echo -e "${GREEN}Creating project: ${PROJECT_NAME} with .NET ${NET_VERSION} (${TARGET_FRAMEWORK})${NC}"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="${SCRIPT_DIR}/${PROJECT_NAME}"

# Check if project directory already exists
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Error: Directory ${PROJECT_DIR} already exists${NC}"
    exit 1
fi

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "${PROJECT_DIR}/src/${PROJECT_NAME}.Domain"
mkdir -p "${PROJECT_DIR}/src/${PROJECT_NAME}.Application"
mkdir -p "${PROJECT_DIR}/src/${PROJECT_NAME}.Infrastructure"
mkdir -p "${PROJECT_DIR}/src/${PROJECT_NAME}.WebApi/Properties"
mkdir -p "${PROJECT_DIR}/tests/${PROJECT_NAME}.Application.UnitTests"
mkdir -p "${PROJECT_DIR}/tests/${PROJECT_NAME}.Domain.UnitTests"
mkdir -p "${PROJECT_DIR}/tests/${PROJECT_NAME}.Infrastructure.UnitTests"

# Create solution file
echo -e "${YELLOW}Creating solution file...${NC}"
cat > "${PROJECT_DIR}/${PROJECT_NAME}.slnx" << EOF
<Solution>
  <Folder Name="/src/">
    <Project Path="src/${PROJECT_NAME}.Application/${PROJECT_NAME}.Application.csproj" />
    <Project Path="src/${PROJECT_NAME}.Domain/${PROJECT_NAME}.Domain.csproj" />
    <Project Path="src/${PROJECT_NAME}.Infrastructure/${PROJECT_NAME}.Infrastructure.csproj" />
    <Project Path="src/${PROJECT_NAME}.WebApi/${PROJECT_NAME}.WebApi.csproj" />
  </Folder>
  <Folder Name="/tests/">
    <Project Path="tests/${PROJECT_NAME}.Application.UnitTests/${PROJECT_NAME}.Application.UnitTests.csproj" />
    <Project Path="tests/${PROJECT_NAME}.Domain.UnitTests/${PROJECT_NAME}.Domain.UnitTests.csproj" />
    <Project Path="tests/${PROJECT_NAME}.Infrastructure.UnitTests/${PROJECT_NAME}.Infrastructure.UnitTests.csproj" />
  </Folder>
</Solution>
EOF

# Create global.json
echo -e "${YELLOW}Creating global.json...${NC}"
cat > "${PROJECT_DIR}/global.json" << EOF
{
  "sdk": {
    "version": "${NET_VERSION}.100",
    "rollForward": "latestFeature"
  }
}
EOF

# Create docker-compose.yml
echo -e "${YELLOW}Creating docker-compose.yml...${NC}"
cat > "${PROJECT_DIR}/docker-compose.yml" << 'EOF'
version: "3.9"
services:
  rabbitmq:
    image: masstransit/rabbitmq:latest
    container_name: rabbitmq
    ports:
      - 5672:5672
      - 15672:15672
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - my-network

  aspire-dashboard:
    image: mcr.microsoft.com/dotnet/nightly/aspire-dashboard:8.0.0-preview.6
    container_name: aspire-dashboard
    environment:
      - DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS=true
    ports:
      - 18888:18888
      - 4317:18889
    networks:
      - my-network
      
  redis:
    image: redis:latest
    command: /bin/sh -c "redis-server --requirepass Th3_P@ssw0rd-421"
    restart: always
    container_name: redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - my-network
      
  mailhog:
    image: mailhog/mailhog
    container_name: mailhog
    ports:
      - "1025:1025" 
      - "8025:8025"
      
  keycloak_web:
    image: quay.io/keycloak/keycloak:23.0.7
    container_name: keycloak_web
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://posgresdb:5432/keycloak
      KC_DB_USERNAME: sa_user
      KC_DB_PASSWORD: Th3_P@ssw0rd-421

      KC_HOSTNAME: localhost
      KC_HOSTNAME_PORT: 8080
      KC_HOSTNAME_STRICT: false
      KC_HOSTNAME_STRICT_HTTPS: false

      KC_LOG_LEVEL: info
      KC_METRICS_ENABLED: true
      KC_HEALTH_ENABLED: true
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
    command: start-dev
    depends_on:
      - posgresdb
    ports:
      - 8080:8080

  posgresdb:
    image: postgres:15
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: sa_user
      POSTGRES_PASSWORD: Th3_P@ssw0rd-421 
    ports:
      - "5432:5432"
      
volumes:
  rabbitmq_data:
  redis_data:
  postgres_data:
  
networks:
  my-network:
EOF

# Create Domain project
echo -e "${YELLOW}Creating Domain project...${NC}"
cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.Domain/${PROJECT_NAME}.Domain.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>${TARGET_FRAMEWORK}</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

</Project>
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.Domain/Entity.cs" << EOF
namespace ${PROJECT_NAME}.Domain
{
    public abstract class Entity
    {
        private List<IDomainEvent>? _domainEvents;
        public IReadOnlyCollection<IDomainEvent> DomainEvents => _domainEvents ?? (IReadOnlyCollection<IDomainEvent>)new List<IDomainEvent>();
        protected void AddDomainEvent(IDomainEvent domainEvent)
            => (_domainEvents ??= new List<IDomainEvent>()).Add(domainEvent);
        public void ClearDomainEvents() => this._domainEvents?.Clear();
    }
}
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.Domain/DomainException.cs" << EOF
namespace ${PROJECT_NAME}.Domain
{
    public class DomainException : Exception
    {
        public DomainException(string message) : base(message)
        {

        }
    }
}
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.Domain/IDomainEvent.cs" << EOF
namespace ${PROJECT_NAME}.Domain
{
    public interface IDomainEvent { }
}
EOF

# Create Application project
echo -e "${YELLOW}Creating Application project...${NC}"
cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.Application/${PROJECT_NAME}.Application.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>${TARGET_FRAMEWORK}</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="MassTransit" Version="8.2.3" />
    <PackageReference Include="FluentValidation" Version="11.10.0" />
    <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\\${PROJECT_NAME}.Domain\\${PROJECT_NAME}.Domain.csproj" />
  </ItemGroup>
</Project>
EOF

# Create Infrastructure project
echo -e "${YELLOW}Creating Infrastructure project...${NC}"
cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.Infrastructure/${PROJECT_NAME}.Infrastructure.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>${TARGET_FRAMEWORK}</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="FluentValidation.AspNetCore" Version="11.3.0" />
    <PackageReference Include="HtmlSanitizer" Version="8.2.871-beta" />
    <PackageReference Include="MassTransit.RabbitMQ" Version="8.2.4-develop.1867" />
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="${NET_VERSION}.0" />
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="${NET_VERSION}.0" />
    <PackageReference Include="Microsoft.Extensions.Caching.StackExchangeRedis" Version="${NET_VERSION}.0" />
    <PackageReference Include="Microsoft.VisualStudio.Azure.Containers.Tools.Targets" Version="1.19.6" />
    <PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="${NET_VERSION}.0" />
    <PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.7.0" />
    <PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.7.0" />
    <PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.7.1" />
    <PackageReference Include="OpenTelemetry.Instrumentation.EntityFrameworkCore" Version="1.0.0-beta.10" />
    <PackageReference Include="OpenTelemetry.Instrumentation.Http" Version="1.7.1" />
    <PackageReference Include="OpenTelemetry.Instrumentation.StackExchangeRedis" Version="1.0.0-rc9.14" />
    <PackageReference Include="StackExchange.Redis" Version="2.8.0" />
    <PackageReference Include="Swashbuckle.AspNetCore.Swagger" Version="${NET_VERSION}.0" />
    <PackageReference Include="Swashbuckle.AspNetCore.SwaggerGen" Version="${NET_VERSION}.0" />
    <PackageReference Include="Swashbuckle.AspNetCore.SwaggerUI" Version="${NET_VERSION}.0" />
    <PackageReference Include="System.Linq.Dynamic.Core" Version="1.4.9" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\\${PROJECT_NAME}.Application\\${PROJECT_NAME}.Application.csproj" />
  </ItemGroup>
</Project>
EOF

# Create WebApi project
echo -e "${YELLOW}Creating WebApi project...${NC}"
cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.WebApi/${PROJECT_NAME}.WebApi.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>${TARGET_FRAMEWORK}</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>true</IsPackable>
  </PropertyGroup>

  <ItemGroup>  
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="${NET_VERSION}.0" />  
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="${NET_VERSION}.0">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>  
    <PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="${NET_VERSION}.0" />  
    <PackageReference Include="Scalar.AspNetCore" Version="1.2.45" />  
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\\${PROJECT_NAME}.Infrastructure\\${PROJECT_NAME}.Infrastructure.csproj" />
  </ItemGroup>

</Project>
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.WebApi/Program.cs" << EOF
var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.WebApi/appsettings.json" << EOF
{
  "AppSettings": {
    "Logging": {
      "LogLevel": {
        "Default": "Debug",
        "Microsoft.AspNetCore": "Debug"
      }
    },
    "MsSql": {
      "ConnectionString": "Host=localhost;Port=5432;Database=${PROJECT_NAME};Username=sa_user;Password=Th3_P@ssw0rd-421"
    },
    "Redis": {
      "Host": "localhost",
      "Port": "6379",
      "Password": "Th3_P@ssw0rd-421"
    },
    "Telemetry": {
      "Host": "http://localhost",
      "Port": "4317",
      "Name": "${PROJECT_NAME}"
    },
    "RabbitMq": {
      "Host": "amqp://localhost"
    },
    "Cache": {
      "ExpirationTimeSeconds": 86400
    },
    "Smtp": {
      "Server": "localhost",
      "Port": "1025",
      "User": "",
      "Password": "",
      "EnableSsl": false,
      "EmailFrom": "system@somedomain.com"
    },
    "AllowedHosts": "*",
    "Authentication": {
      "Authority": "http://localhost:8080/realms/e-commerce-realm",
      "Audience": "e-commerce-api-resource-owner-client",
      "ClientId": "e-commerce-api-resource-owner-client",
      "MetadataUrl": "http://localhost:8080/realms/e-commerce-realm/.well-known/openid-configuration",
      "TokenEndpoint": "http://localhost:8080/realms/e-commerce-realm/protocol/openid-connect/token"
    },
    "Cors": {
      "AllowedOrigins": [ "http://localhost:8081" ],
      "AllowedMethods": [ "GET", "POST"],
      "AllowedHeaders": [ "Content-Type", "Authorization" ]
    }
  }
}
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.WebApi/appsettings.Development.json" << EOF
{
  "AppSettings": {
    "Logging": {
      "LogLevel": {
        "Default": "Information",
        "Microsoft.AspNetCore": "Warning"
      }
    }
  }
}
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.WebApi/Properties/launchSettings.json" << EOF
{
  "\$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": false,
      "applicationUrl": "http://localhost:5156",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": false,
      "applicationUrl": "https://localhost:7192;http://localhost:5156",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}.WebApi/${PROJECT_NAME}.WebApi.http" << EOF
@${PROJECT_NAME}.WebApi_HostAddress = http://localhost:5156

GET {{${PROJECT_NAME}.WebApi_HostAddress}}/weatherforecast/
Accept: application/json

###
EOF

# Create test projects
echo -e "${YELLOW}Creating test projects...${NC}"

# Application UnitTests
cat > "${PROJECT_DIR}/tests/${PROJECT_NAME}.Application.UnitTests/${PROJECT_NAME}.Application.UnitTests.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>${TARGET_FRAMEWORK}</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="coverlet.collector" Version="6.0.4" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
    <PackageReference Include="xunit" Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="3.1.4" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="Xunit" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\\..\\src\\${PROJECT_NAME}.Application\\${PROJECT_NAME}.Application.csproj" />
  </ItemGroup>

</Project>
EOF

# Domain UnitTests
cat > "${PROJECT_DIR}/tests/${PROJECT_NAME}.Domain.UnitTests/${PROJECT_NAME}.Domain.UnitTests.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>${TARGET_FRAMEWORK}</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="coverlet.collector" Version="6.0.4" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
    <PackageReference Include="xunit" Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="3.1.4" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="Xunit" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\\..\\src\\${PROJECT_NAME}.Domain\\${PROJECT_NAME}.Domain.csproj" />
  </ItemGroup>

</Project>
EOF

# Infrastructure UnitTests
cat > "${PROJECT_DIR}/tests/${PROJECT_NAME}.Infrastructure.UnitTests/${PROJECT_NAME}.Infrastructure.UnitTests.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>${TARGET_FRAMEWORK}</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="coverlet.collector" Version="6.0.4" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
    <PackageReference Include="xunit" Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="3.1.4" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="Xunit" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\\..\\src\\${PROJECT_NAME}.Infrastructure\\${PROJECT_NAME}.Infrastructure.csproj" />
  </ItemGroup>

</Project>
EOF

# Restore and build
echo -e "${YELLOW}Restoring packages...${NC}"
cd "${PROJECT_DIR}"
dotnet restore

echo -e "${YELLOW}Building solution...${NC}"
dotnet build

echo -e "${GREEN}✓ Project ${PROJECT_NAME} created successfully!${NC}"
echo -e "${GREEN}✓ Location: ${PROJECT_DIR}${NC}"
echo -e "${GREEN}✓ .NET Version: ${NET_VERSION} (${TARGET_FRAMEWORK})${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  cd ${PROJECT_DIR}"
echo "  dotnet run --project src/${PROJECT_NAME}.WebApi/${PROJECT_NAME}.WebApi.csproj"
