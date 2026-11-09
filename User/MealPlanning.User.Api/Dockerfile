FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish User/MealPlanning.User.Api/MealPlanning.User.Api.csproj -c Release -o /app/publish --no-self-contained

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENTRYPOINT ["dotnet", "MealPlanning.User.Api.dll"]
