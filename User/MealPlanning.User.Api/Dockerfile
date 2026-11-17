FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
USER $APP_UID
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080
ENV TZ=Asia/Yangon
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["User/MealPlanning.User.Api/MealPlanning.User.Api.csproj", "User/MealPlanning.User.Api/"]
COPY ["User/MealPlanning.User.Application/MealPlanning.User.Application.csproj", "User/MealPlanning.User.Application/"]
COPY ["User/MealPlanning.User.Domain/MealPlanning.User.Domain.csproj", "User/MealPlanning.User.Domain/"]
COPY ["User/MealPlanning.User.Infrastructure/MealPlanning.User.Infrastructure.csproj", "User/MealPlanning.User.Infrastructure/"]
COPY ["Shared/MealPlanning.Shared.Hosting/MealPlanning.Shared.Hosting.csproj", "Shared/MealPlanning.Shared.Hosting/"]
COPY ["Shared/MealPlanning.Shared.Hosting/ConfigAssets.targets", "Shared/MealPlanning.Shared.Hosting/"]
COPY ["Directory.Build.props", "."]
COPY ["Config", "Config"]
RUN dotnet restore "User/MealPlanning.User.Api/MealPlanning.User.Api.csproj"
COPY . .
WORKDIR "/src/User/MealPlanning.User.Api"
RUN dotnet build "MealPlanning.User.Api.csproj" -c $BUILD_CONFIGURATION -o /app/build --no-restore

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "MealPlanning.User.Api.csproj" -c $BUILD_CONFIGURATION -o /app/publish --no-restore --no-self-contained

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MealPlanning.User.Api.dll"]
