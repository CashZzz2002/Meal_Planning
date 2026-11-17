FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
USER $APP_UID
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080
ENV TZ=Asia/Yangon
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["Admin/MealPlanning.Admin.Api/MealPlanning.Admin.Api.csproj", "Admin/MealPlanning.Admin.Api/"]
COPY ["Admin/MealPlanning.Admin.Application/MealPlanning.Admin.Application.csproj", "Admin/MealPlanning.Admin.Application/"]
COPY ["Admin/MealPlanning.Admin.Domain/MealPlanning.Admin.Domain.csproj", "Admin/MealPlanning.Admin.Domain/"]
COPY ["Admin/MealPlanning.Admin.Infrastructure/MealPlanning.Admin.Infrastructure.csproj", "Admin/MealPlanning.Admin.Infrastructure/"]
COPY ["Shared/MealPlanning.Shared.Hosting/MealPlanning.Shared.Hosting.csproj", "Shared/MealPlanning.Shared.Hosting/"]
COPY ["Shared/MealPlanning.Shared.Hosting/ConfigAssets.targets", "Shared/MealPlanning.Shared.Hosting/"]
COPY ["Directory.Build.props", "."]
COPY ["Config", "Config"]
RUN dotnet restore "Admin/MealPlanning.Admin.Api/MealPlanning.Admin.Api.csproj"
COPY . .
WORKDIR "/src/Admin/MealPlanning.Admin.Api"
RUN dotnet build "MealPlanning.Admin.Api.csproj" -c $BUILD_CONFIGURATION -o /app/build --no-restore

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "MealPlanning.Admin.Api.csproj" -c $BUILD_CONFIGURATION -o /app/publish --no-restore --no-self-contained

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MealPlanning.Admin.Api.dll"]
