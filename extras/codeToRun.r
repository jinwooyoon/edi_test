library(EdiToOmop)

##Environment Settings
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sql server",
                                                                server = "",
                                                                user = "",
                                                                password = "",
                                                                port = "",
\                                                               pathToDriver = "~/jdbc"
)


dbName <- "EDI_OMOP"
schema <- "dbo"
vocaTableName = "edi_voca_table" ##Table name for vocabulary
###########################


#### preprocessing ####

deviceData<-EdiToOmop::DeviceProcess(exelFilePath="~/EdiToOmop-master/inst/excels/Device2019.10.1.xlsx",
                                     sheetName = "급여품목(인체조직포함)",
                                     materialData=NULL,
                                     deviceCode = "코 드",
                                     deviceName = "품 명",
                                     startDateName="적용일자",
                                     materialName = "재 질",
                                     KoreanDictFile="~/EdiToOmop-master/inst/csv/tmt_Eng_Kor_translation.csv")




sugaData <- EdiToOmop::SugaProcess(exelFilePath = "~/EdiToOmop-master/inst/excels/Suga2023.07.01.xlsx",
                                   sheetName = "의치과_급여_전체",
                                   sugaData=NULL,
                                   sugaCode = "수가코드",
                                   KoreanName = "한글명",
                                   EnglishName = "영문명",
                                   startDateName = "적용일자",
                                   sanjungName = "산정명칭",
                                   KoreanDictFile="./inst/csv/result_suga_translate.csv"
)

drugData<-EdiToOmop::DrugProcess(exelFilePath = "~/EdiToOmop-master/inst/excels/Drug2023.08.01.xlsx",
                                 sheetName="약가통신제공",
                                 drugData=NULL,
                                 drugCode = "약품코드",
                                 drugName = "품명",
                                 clinicalDrugcode = "주성분코드",
                                 drugDosage = "규격",
                                 drugDosageUnit = "단위",
                                 previousConceptCode = "변경이전")

ediData=rbind(deviceData,drugData,sugaData)


#ediData<-ediData[order(ediData$concept_code),]

max(nchar(ediData$conceptSynonym)) # we will allow lengthy concept name

## del duplicated
dupl<-ediData[duplicated(ediData$conceptCode) | duplicated(ediData$conceptCode, fromLast=TRUE),]
dupl_del<-dupl[dupl$domainId !="Device",]
dupl_add<-dupl[dupl$domainId =="Device",]

ediData<-ediData[!(ediData$conceptCode %in% dupl$conceptCode),]
ediData<-rbind(ediData, dupl_add)

rm(dupl, dupl_add, dupl_del)

#We will insert these data into the database.
#Be careful! This function will remove the table(tableName) and re-generate it.

EdiToOmop::GenerateEdiVocaTable(ediData = ediData,
                                connectionDetails = connectionDetails,
                                databaseName = dbName,
                                vocabularyDatabaseSchema = schema,
                                tableName = vocaTableName,
                                useMppBulkLoadS = FALSE
)





CreateCsv(ediData = ediData,
          filePath = "~/EdiData.csv"
)








#### update ####

##Create new Device dataframe




newDeviceData<-EdiToOmop::DeviceProcess(exelFilePath="./inst/excels/Device2023.07.01(merge).xlsx",
                                        sheetName = "result",
                                        materialData=NULL,
                                        deviceCode = "코 드",
                                        deviceName = "품 명",
                                        startDateName="적용일자",
                                        materialName = "재 질",
                                        KoreanDictFile="./inst/csv/tmt_Eng_Kor_translation.csv")


##Update the existing table

EdiToOmop::NewEdiUpdate(ediData = newDeviceData,
                        startDate = "2023-07-01",
                        databaseName = dbName,
                        schema = schema,
                        domainIds = c("Device"),
                        existingVocaTable = vocaTableName,
                        connectionDetails = connectionDetails
)



##Create new Drug dataframe
newDrugData<-EdiToOmop::DrugProcess(exelFilePath = "./inst/excels/Drug2023.08.01.xlsx",
                                    sheetName=NULL,
                                    drugData=NULL,
                                    drugCode = "약품코드",
                                    drugName = "품명",
                                    clinicalDrugcode = "주성분코드",
                                    drugDosage = "규격",
                                    drugDosageUnit = "단위",
                                    previousConceptCode = "변경이전")


##Update the existing table

EdiToOmop::NewEdiUpdate(ediData = newDrugData,
                        startDate = "2019-11-01",
                        domainIds = c("Drug"),
                        databaseName = dbName,
                        schema = schema,
                        existingVocaTable = vocaTableName,
                        connectionDetails = connectionDetails
)





##Create new Suga dataframe
newSugaData<-EdiToOmop::SugaProcess(exelFilePath = "./inst/excels/Suga2023.08.01.xlsx",
                                    sheetName = "의치과_급여_전체",       ##Watch out! the name of the target sheet was changed.
                                    sugaData=NULL,
                                    sugaCode = "수가코드",
                                    KoreanName = "한글명",
                                    EnglishName = "영문명",
                                    startDateName = "적용일자",
                                    sanjungName = "산정명칭",
                                    KoreanDictFile="./inst/csv/result_suga_translate.csv"
)

sum(is.na(newSugaData$conceptName)) #There are concept names not trasnlated into English.

#newSugaData[is.na(newSugaData)] <- 0
##Update the existing table


EdiToOmop::NewEdiUpdate(ediData = newSugaData,
                        startDate = "2023-08-01",
                        domainIds = c("Procedure", "Measurement"),
                        databaseName = dbName,
                        schema = schema,
                        existingVocaTable = vocaTableName,
                        connectionDetails = connectionDetails
)

######

