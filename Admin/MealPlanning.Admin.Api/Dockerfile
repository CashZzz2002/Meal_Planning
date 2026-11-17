FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src

COPY . .

RUN dotnet restore Admin/MealPlanning.Admin.Api/MealPlanning.Admin.Api.csproj

RUN dotnet publish Admin/MealPlanning.Admin.Api/MealPlanning.Admin.Api.csproj --configuration Release --output /app/publish --no-restore --no-self-contained

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime

WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
ENV TZ=Asia/Yangon

EXPOSE 8080

ENTRYPOINT ["dotnet", "MealPlanning.Admin.Api.dll"]