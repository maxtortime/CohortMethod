# @file SingleStudyVignetteDataFetch.R
#
# Copyright 2018 Observational Health Data Sciences and Informatics
#
# This file is part of CohortMethod
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This code should be used to fetch the data that is used in the vignettes.
library(SqlRender)
library(DatabaseConnector)
library(CohortMethod)
options(fftempdir = "s:/fftemp")

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "postgresql",
                                                                server = "localhost/ohdsi",
                                                                user = "postgres",
                                                                password = Sys.getenv("pwPostgres"))
cdmDatabaseSchema <- "cdm_synpuf"
resultsDatabaseSchema <- "scratch"
cdmVersion <- "5"
extraSettings <- NULL

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "pdw",
                                                                server = Sys.getenv("PDW_SERVER"),
                                                                user = NULL,
                                                                password = NULL,
                                                                port = Sys.getenv("PDW_PORT"))
cdmDatabaseSchema <- "cdm_truven_mdcd_v610.dbo"
resultsDatabaseSchema <- "scratch.dbo"
cdmVersion <- "5"
extraSettings <- NULL

connection <- DatabaseConnector::connect(connectionDetails)
sql <- loadRenderTranslateSql("coxibVsNonselVsGiBleed.sql",
                              packageName = "CohortMethod",
                              dbms = connectionDetails$dbms,
                              cdmDatabaseSchema = cdmDatabaseSchema,
                              resultsDatabaseSchema = resultsDatabaseSchema)
DatabaseConnector::executeSql(connection, sql)

# Check number of subjects per cohort:
sql <- "SELECT cohort_definition_id, COUNT(*) AS count FROM @resultsDatabaseSchema.coxibVsNonselVsGiBleed GROUP BY cohort_definition_id"
sql <- SqlRender::renderSql(sql, resultsDatabaseSchema = resultsDatabaseSchema)$sql
sql <- SqlRender::translateSql(sql, targetDialect = connectionDetails$dbms)$sql
DatabaseConnector::querySql(connection, sql)

DatabaseConnector::disconnect(connection)

nsaids <- 21603933

covSettings <- createDefaultCovariateSettings(excludedCovariateConceptIds = nsaids,
                                              addDescendantsToExclude = TRUE)

# Load data:
cohortMethodData <- getDbCohortMethodData(connectionDetails = connectionDetails,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          oracleTempSchema = resultsDatabaseSchema,
                                          targetId = 1,
                                          comparatorId = 2,
                                          outcomeIds = 3,
                                          studyStartDate = "",
                                          studyEndDate = "",
                                          exposureDatabaseSchema = resultsDatabaseSchema,
                                          exposureTable = "coxibVsNonselVsGiBleed",
                                          outcomeDatabaseSchema = resultsDatabaseSchema,
                                          outcomeTable = "coxibVsNonselVsGiBleed",
                                          cdmVersion = cdmVersion,
                                          excludeDrugsFromCovariates = FALSE,
                                          firstExposureOnly = TRUE,
                                          removeDuplicateSubjects = "remove all",
                                          restrictToCommonPeriod = FALSE,
                                          washoutPeriod = 180,
                                          covariateSettings = covSettings)

saveCohortMethodData(cohortMethodData, "s:/temp/cohortMethodVignette/cohortMethodData")

# cohortMethodData <- loadCohortMethodData('s:/temp/cohortMethodVignette/cohortMethodData')

# summary(cohortMethodData) getAttritionTable(cohortMethodData)

studyPop <- createStudyPopulation(cohortMethodData = cohortMethodData,
                                  outcomeId = 3,
                                  firstExposureOnly = FALSE,
                                  washoutPeriod = 0,
                                  removeDuplicateSubjects = FALSE,
                                  removeSubjectsWithPriorOutcome = TRUE,
                                  minDaysAtRisk = 1,
                                  riskWindowStart = 0,
                                  addExposureDaysToStart = FALSE,
                                  riskWindowEnd = 30,
                                  addExposureDaysToEnd = TRUE)
# getAttritionTable(studyPop)

saveRDS(studyPop, "s:/temp/cohortMethodVignette/studyPop.rds")

# studyPop <- readRDS('s:/temp/cohortMethodVignette/studyPop.rds')

ps <- createPs(cohortMethodData = cohortMethodData,
               population = studyPop,
               prior = createPrior("laplace", exclude = c(0), useCrossValidation = TRUE),
               control = createControl(cvType = "auto",
                                       startingVariance = 0.01,
                                       noiseLevel = "quiet",
                                       tolerance = 2e-07,
                                       cvRepetitions = 1,
                                       threads = 10))

# computePsAuc(ps) plotPs(ps)
saveRDS(ps, file = "s:/temp/cohortMethodVignette/ps.rds")
# ps <- readRDS('s:/temp/cohortMethodVignette/ps.rds')
model <- getPsModel(ps, cohortMethodData)
model[grepl("Charlson.*", model$covariateName), ]
model[model$id %% 1000 == 902, ]

# insertDbPopulation(population = studyPop, cohortIds = c(101,100), connectionDetails =
# connectionDetails, cohortDatabaseSchema = resultsDatabaseSchema, cohortTable = 'mschuemi_test',
# createTable = TRUE, dropTableIfExists = TRUE, cdmVersion = 5)

# Check number of subjects per cohort: connection <- DatabaseConnector::connect(connectionDetails)
# sql <- 'SELECT cohort_definition_id, COUNT(*) AS count FROM @resultsDatabaseSchema.mschuemi_test
# GROUP BY cohort_definition_id' sql <- SqlRender::renderSql(sql, resultsDatabaseSchema =
# resultsDatabaseSchema)$sql sql <- SqlRender::translateSql(sql, targetDialect =
# connectionDetails$dbms)$sql DatabaseConnector::querySql(connection, sql) dbDisconnect(connection)

# trimmed <- trimByPs(ps) trimmed <- trimByPsToEquipoise(ps) plotPs(trimmed, ps)

matchedPop <- matchOnPs(ps, caliper = 0.25, caliperScale = "standardized", maxRatio = 1)
# getAttritionTable(matchedPop) plotPs(matchedPop, ps)

balance <- computeCovariateBalance(matchedPop, cohortMethodData)

saveRDS(balance, file = "s:/temp/cohortMethodVignette/balance.rds")

# balance <- readRDS('s:/temp/cohortMethodVignette/balance.rds')

table1 <- createCmTable1(balance)
print(table1, row.names = FALSE, right = FALSE)
plotCovariateBalanceScatterPlot(balance, fileName = "s:/temp/scatter.png")
# plotCovariateBalanceOfTopVariables(balance, fileName = "s:/temp/top.png")

outcomeModel <- fitOutcomeModel(population = studyPop,
                                modelType = "cox",
                                stratified = FALSE,
                                useCovariates = FALSE)
# getAttritionTable(outcomeModel) outcomeModel summary(outcomeModel) coef(outcomeModel)
# confint(outcomeModel)
saveRDS(outcomeModel, file = "s:/temp/cohortMethodVignette/OutcomeModel1.rds")

outcomeModel <- fitOutcomeModel(population = matchedPop,
                                modelType = "cox",
                                stratified = TRUE,
                                useCovariates = FALSE)
saveRDS(outcomeModel, file = "s:/temp/cohortMethodVignette/OutcomeModel2.rds")
weights <- ps$treatment / ps$propensityScore + (1-ps$treatment) / (1-ps$propensityScore)
max(weights)
min(weights)

outcomeModel <- fitOutcomeModel(population = ps,
                                modelType = "cox",
                                stratified = FALSE,
                                useCovariates = FALSE,
                                inversePsWeighting = TRUE)
outcomeModel
saveRDS(outcomeModel, file = "s:/temp/cohortMethodVignette/OutcomeModel2w.rds")


outcomeModel <- fitOutcomeModel(population = matchedPop,
                                cohortMethodData = cohortMethodData,
                                modelType = "cox",
                                stratified = TRUE,
                                useCovariates = TRUE,
                                prior = createPrior("laplace", useCrossValidation = TRUE),
                                control = createControl(cvType = "auto",
                                                        startingVariance = 0.01,
                                                        selectorType = "byPid",
                                                        cvRepetitions = 1,
                                                        tolerance = 2e-07,
                                                        threads = 16,
                                                        noiseLevel = "quiet"))
saveRDS(outcomeModel, file = "s:/temp/cohortMethodVignette/OutcomeModel3.rds")




# outcomeModel <- readRDS(file = 's:/temp/cohortMethodVignette/OutcomeModel3.rds')
# drawAttritionDiagram(outcomeModel, fileName = 's:/temp/attrition.png') summary(outcomeModel)
