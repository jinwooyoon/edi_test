
drugData <- readxl::read_excel("./inst/excels/Drug2019.10.1.xlsx",
                               sheet = NULL,
                               col_names = TRUE)

drugCode <- "제품코드"
clinicalDrugcode <-"주성분코드"
previousConceptCode <-"목록정비전코드"
drugDosage<-"규격"
drugDosageUnit<-"단위"
drugName<-"제품명"
#
# drugCode <- "약품코드"
# clinicalDrugcode <-"주성분코드"
# previousConceptCode <-"변경이전"
# drugDosage<-"규격"
# drugDosageUnit<-"단위"
# drugName<-"품명"

conceptCode <- dplyr::pull(drugData, drugCode)
ancestorConceptCode <- dplyr::pull(drugData, clinicalDrugcode)
previousConceptCode <- dplyr::pull(drugData, previousConceptCode)
drugDosage <- dplyr::pull(drugData, drugDosage)
drugDosageUnit <- dplyr::pull(drugData, drugDosageUnit)
conceptSynonym <- dplyr::pull(drugData, drugName)


mdcDf <- dplyr::data_frame(conceptCode = conceptCode,
                           conceptName = conceptCode,
                           conceptSynonym = conceptSynonym,
                           domainId = "Drug",
                           vocabularyId = "EDI",
                           conceptClassId = "Drug Product",
                           validStartDate = as.Date("1970-01-01"),
                           validEndDate = as.Date("2099-12-31"),
                           invalidReason = NA,
                           ancestorConceptCode = ancestorConceptCode,
                           previousConceptCode = previousConceptCode,
                           material=NA,
                           dosage = as.numeric(drugDosage),
                           dosageUnit = drugDosageUnit,
                           sanjungName = NA,
                           stringsAsFactors=FALSE)



mdcDf$vocabularyId[is.na(mdcDf$conceptSynonym)] <- "KDC"
mdcDf$conceptClassId[mdcDf$vocabularyId=="KDC"] <- "Clinical Drug"

kdcDf<-mdcDf[mdcDf$vocabularyId=="KDC",]

drugNameDf <- kdcDf[c("conceptName", "ancestorConceptCode")]
#paste drug names for the same clinical drug (composite drug)
drugNameDf <- aggregate(conceptName ~ ancestorConceptCode, data = drugNameDf, paste, collapse = ",")


bdgDf <- mdcDf[mdcDf$vocabularyId=="EDI",]
bdgDf$conceptName <- NULL

#Set the name of Branded Drug as Clinical Drug Names
bdgDf <- merge(bdgDf,drugNameDf, by = "ancestorConceptCode", all.x= TRUE, all.y = FALSE)

bdgDf <- bdgDf[c("conceptCode", "conceptName", "conceptSynonym", "domainId", "vocabularyId", "conceptClassId",
                 "validStartDate", "validEndDate", "invalidReason","ancestorConceptCode","previousConceptCode",
                 "material", "dosage", "dosageUnit","sanjungName")]


connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sql server",
                                                                server = "10.19.10.248",
                                                                user = "sa",
                                                                password = "yonsei202208!@",
                                                                port = "1433",
                                                                pathToDriver = "~/jdbc"
)
conn <- DatabaseConnector::connect(connectionDetails)
tableName <- "temp_table"

vocabularyDatabaseSchema <- "dbo"

sql<-"IF OBJECT_ID('#@table_name', 'U') IS NOT NULL
	DROP TABLE #@table_name;

  CREATE TABLE #@table_name (
  concept_code			  	VARCHAR(50)		NOT NULL ,
  concept_name			  	VARCHAR(2000)	NOT NULL ,  --Please note that we allowed lengthy concept name
  concept_synonym       VARCHAR(2000)	NULL,
  domain_id				      VARCHAR(20)		NOT NULL ,
  vocabulary_id			  	VARCHAR(20)		NOT NULL ,
  concept_class_id			VARCHAR(20)		NOT NULL ,
  valid_start_date			DATE			    NOT NULL ,
  valid_end_date		  	DATE	    		NOT NULL ,
  invalid_reason		  	VARCHAR(1)		NULL ,
  ancestor_concept_code VARCHAR(20)		NULL ,
  previous_concept_code VARCHAR(20)		NULL ,
  material              VARCHAR(1000)  NULL ,
  dosage                FLOAT   		NULL ,
  dosage_unit           VARCHAR(20)		NULL ,
  sanjung_name          VARCHAR(1000)		NULL
);
  "

sql <- SqlRender::render(sql,
                         table_name=tableName)

sql <- SqlRender::translate(sql, targetDialect = "sql server")


DatabaseConnector::executeSql(conn,sql)

