###################################################
## Setting up Network Analysis
## And ranking draft
###################################################
# Samuel Katz
# July 27, 2017
# modified by Jian Song
###################################################

# require('edgebundleR')                        #Load Libraries
# library('igraph')
# library('data.table')
# library('dplyr')

#selectedRows <- c(1,2,3)  
#Generate_NetworkGraph(selectedRows)

Generate_NetworkGraph <- function(selectedRows, organism, G){
  #############################################################
  #Set directories
  
  cat(file=stderr(), "inside Rnaking_plusComments_v3\n")
  
  SIGNAL.input <- dataDir                                             
  
  SIGNALhits <- SIGNALoutput.condensed                                      
  
  
  #Get pathway file
  pathwayFile <- pathwayData      
  
  
  #Get Matrix of genes for each pathway in KEGG                    
  # Putting the list of gene EntrezID for each pathway of interest into a matrix
  
  path1_name <<- sigPathways$Pathway[as.numeric(selectedRows[1])]     
  #message(path1_name)
  path1_pathway.genes <- filter(pathwayFile, PathwayName == path1_name)
  path1_pathway.genes.matrix <- matrix(path1_pathway.genes$EntrezID)
  
  
  path2_name <<- sigPathways$Pathway[as.numeric(selectedRows[2])]   
  #message(path2_name)
  path2_pathway.genes <- filter(pathwayFile, PathwayName == path2_name)
  path2_pathway.genes.matrix <- matrix(path2_pathway.genes$EntrezID)
  
  
  path3_name <<- sigPathways$Pathway[as.numeric(selectedRows[3])]    
  #message(path3_name)
  path3_pathway.genes <- filter(pathwayFile, PathwayName == path3_name)
  path3_pathway.genes.matrix <- matrix(path3_pathway.genes$EntrezID)
  
  
  path1_hits <- filter(SIGNALhits, EntrezID %in% path1_pathway.genes.matrix)
  path1_hits.matrix <- matrix(path1_hits$EntrezID)
  
  path2_hits <- filter(SIGNALhits, EntrezID %in% path2_pathway.genes.matrix)
  path2_hits.matrix <- matrix(path2_hits$EntrezID)
  
  path3_hits <- filter(SIGNALhits, EntrezID %in% path3_pathway.genes.matrix)
  path3_hits.matrix <- matrix(path3_hits$EntrezID)
  
  
  #######################################                                            # redoing the pathway gene matrices to be of the gene symbol instead of the Entrez ID
  #Get Matrix of genes for each pathway in KEGG
  path1_pathway.genes.matrix <- matrix(path1_pathway.genes$GeneSymbol)
  
  path2_pathway.genes.matrix <- matrix(path2_pathway.genes$GeneSymbol)
  
  path3_pathway.genes.matrix <- matrix(path3_pathway.genes$GeneSymbol)

  
  SIGNALhits.matrix <- matrix(SIGNALhits$EntrezID)                      # Created a matrix of all the genes that are "hits"
  
  
  
  
  
  #Get matrices for Pathways (Hits and non hits seperately)      # Now creating seperate matrices for each pathway containing only the genes of that pathway that are ALSO hits in the screen
  #Hits

  
  
  
  #Add GeneSymbols to Edge dataframe                                              
  Edge.source <- merge(EdgeInfo, NodeInfo[, c("GeneMappingID", "GeneSymbol")], by.x = "source", by.y = "GeneMappingID", all.x = TRUE)
  
  names(Edge.source)[names(Edge.source)=="GeneSymbol"] <- "source.ID"
  
  Edge.target <- merge(Edge.source, NodeInfo[, c("GeneMappingID", "GeneSymbol")], by.x = "target", by.y = "GeneMappingID", all.x = TRUE)
  
  names(Edge.target)[names(Edge.target)=="GeneSymbol"] <- "target.ID"
  
  #Set column for pathway groupings
  NodeInfo$Group <- "Novel"
  
  NodeInfo$Group[NodeInfo$GeneSymbol %in% path1_pathway.genes.matrix] <- path1_name
  
  NodeInfo$Group[NodeInfo$GeneSymbol %in% path2_pathway.genes.matrix] <- path2_name        
  
  NodeInfo$Group[NodeInfo$GeneSymbol %in% path3_pathway.genes.matrix] <- path3_name
  
  #Merge Pathway, and SIGNALhits to NodeInfo
  Scores_and_nodes <- merge(NodeInfo[, c("GeneMappingID", "GeneSymbol", "Group")],                      #Pairing up the "Node Info" with the gene info (such as gene symbol and groupings)
                            SIGNALhits[, c("GeneSymbol", "EntrezID", "ConfidenceCategory", "Pathway")], 
                            by.x = "GeneSymbol", by.y = "GeneSymbol", all.x = T)
  
  
  #Aggregate the edges to be summarised to each genemap ID                                            #pulling together all genes that interactect with a specifc gene and putting them in one row seprated by comma
  Edge_source_summary <- aggregate(target.ID ~ source.ID, data = Edge.target, paste, collapse = ", ")
  Edge_target_summary <- aggregate(source.ID ~ target.ID, data = Edge.target, paste, collapse = ", ")
  
  
  #Align column names and stack data frames                                                         #The analysis assumed directionality of interactions, but we're ignoring it here, so combining the "target" and Source" to one dataframe.
  colnames(Edge_target_summary) <- c("source.ID", "target.ID")
  Edge_summary_stacked <- rbind(Edge_source_summary, Edge_target_summary)
  
  #Aggregate stacked data to get unique values
  Edge_summary <- aggregate(target.ID ~ source.ID, data = Edge_summary_stacked, paste, collapse = ", ")
  
  #Update Names                                                                                     #Now a dataframe is being created where each gene selected by SIGNAL (or part of the highlighted groups) has a list "Ntwrk.all" that lists all other genes from TRAIGE that it is predicted to interact with.
  colnames(Edge_summary) <- c("GeneSymbol", "Ntwrk.all")
  
  #Merge with scores 
  Scores_nodes_and_edges <- merge(Scores_and_nodes, Edge_summary, by.x = "GeneSymbol", by.y = "GeneSymbol", all.x = T)
  
  #Create column with counts for interacting genes                                               #Here a counter is added, this counts for each gene how many genes (within the SIGNAL set) are predicted to have interactions with it, (this allows to then list your hits based on how many interactions it has with other hits)
  for (i in 1:length(Scores_nodes_and_edges$Ntwrk.all)) {
    Scores_nodes_and_edges$Allnet.count[i] <- ifelse(is.na(Scores_nodes_and_edges$Ntwrk.all[i]) == T, 0, 
                                                     length(unlist(strsplit(Scores_nodes_and_edges$Ntwrk.all[i], ", "))))
  }
  #Like the "counter" for all the network genes, now setting up seperate counter for each pahway of interest. Within pathways you want to seperate wther the gene it is interacting with is also a "hit" in SIGNAL or is it just a gene in that pathway that is not a hit.  ########################################### Create Matrices of the genes within each group that are also hits in the screen
  
  ########################################### Create Matrices of the genes within each group that are also hits in the screen
  #Pathway#1 Hit Genes 
  path1_hits.genes <- filter(Scores_nodes_and_edges, Group == path1_name & EntrezID %in% SIGNALhits.matrix)
  path1_hits.genes.matrix <- matrix(path1_hits.genes$GeneSymbol)
  
  #Pathway#2 Hit Genes 
  
  path2_hits.genes <- filter(Scores_nodes_and_edges, Group == path2_name & EntrezID %in% SIGNALhits.matrix)
  path2_hits.genes.matrix <- matrix(path2_hits.genes$GeneSymbol)
  
  #Pathway#3 Hit Genes 
  
  path3_hits.genes <- filter(Scores_nodes_and_edges, Group == path3_name & EntrezID %in% SIGNALhits.matrix)
  path3_hits.genes.matrix <- matrix(path3_hits.genes$GeneSymbol)
  
  #Now for each "pathway" or group you do a seperate count, first pulling out the genes from the network column related to it, then counting how many of it it is.          
  
  ##################################### Create list and rankings by group hits ##############################             #This is the same process as above only instead of looking for the number of genes in the group it looks at genes in the group that are also "hits"
  
  
  ############################# path1_ Hits Genes
  
  #Create Blank
  Scores_nodes_and_edges$Ntwrk.path1_.hits <- NA
  group.list <- path1_hits.genes.matrix
  
  #Extract genes from network interaction associted with genes from group
  for (i in 1:length(group.list)) {
    temp.name <- group.list[i]
    out <- grep(paste0("\\b", temp.name, "\\b"), Scores_nodes_and_edges[["Ntwrk.all"]], value = F, fixed = F)
    Scores_nodes_and_edges$Ntwrk.path1_.hits[out] <- paste(temp.name, Scores_nodes_and_edges$Ntwrk.path1_.hits[out], sep = ", ")
  }
  
  #remove "NA" from rows with genes in them
  Scores_nodes_and_edges$Ntwrk.path1_.hits <- gsub(", NA", "", Scores_nodes_and_edges$Ntwrk.path1_)
  
  #Create column with counts for interacting genes
  for (i in 1:length(Scores_nodes_and_edges$Ntwrk.path1_.hits)) {
    Scores_nodes_and_edges$path1_hits.net.count[i] <- ifelse(is.na(Scores_nodes_and_edges$Ntwrk.path1_.hits[i]) == T, 0, 
                                                             length(unlist(strsplit(Scores_nodes_and_edges$Ntwrk.path1_[i], ", "))))
  }
  
  ############################# path2_ Hits Genes
  
  #Create Blank
  Scores_nodes_and_edges$Ntwrk.path2_.hits <- NA
  group.list <- path2_hits.genes.matrix
  
  #Extract genes from network interaction associted with genes from group
  for (i in 1:length(group.list)) {
    temp.name <- group.list[i]
    out <- grep(paste0("\\b", temp.name, "\\b"), Scores_nodes_and_edges[["Ntwrk.all"]], value = F, fixed = F)
    Scores_nodes_and_edges$Ntwrk.path2_.hits[out] <- paste(temp.name, Scores_nodes_and_edges$Ntwrk.path2_.hits[out], sep = ", ")
  }
  
  #remove "NA" from rows with genes in them
  Scores_nodes_and_edges$Ntwrk.path2_.hits <- gsub(", NA", "", Scores_nodes_and_edges$Ntwrk.path2_.hits)
  
  #Create column with counts for interacting genes
  for (i in 1:length(Scores_nodes_and_edges$Ntwrk.path2_.hits)) {
    Scores_nodes_and_edges$path2_hits.net.count[i] <- ifelse(is.na(Scores_nodes_and_edges$Ntwrk.path2_.hits[i]) == T, 0, 
                                                             length(unlist(strsplit(Scores_nodes_and_edges$Ntwrk.path2_.hits[i], ", "))))
  }
  
  ############################# path3_ Hits Genes
  
  #Create Blank
  Scores_nodes_and_edges$Ntwrk.path3_.hits <- NA
  group.list <- path3_hits.genes.matrix
  
  #Extract genes from network interaction associted with genes from group
  for (i in 1:length(group.list)) {
    temp.name <- group.list[i]
    out <- grep(paste0("\\b", temp.name, "\\b"), Scores_nodes_and_edges[["Ntwrk.all"]], value = F, fixed = F)
    Scores_nodes_and_edges$Ntwrk.path3_.hits[out] <- paste(temp.name, Scores_nodes_and_edges$Ntwrk.path3_.hits[out], sep = ", ")
  }
  
  #remove "NA" from rows with genes in them
  Scores_nodes_and_edges$Ntwrk.path3_.hits <- gsub(", NA", "", Scores_nodes_and_edges$Ntwrk.path3_.hits)
  
  #Create column with counts for interacting genes
  for (i in 1:length(Scores_nodes_and_edges$Ntwrk.path3_.hits)) {
    Scores_nodes_and_edges$path3_hits.net.count[i] <- ifelse(is.na(Scores_nodes_and_edges$Ntwrk.path3_.hits[i]) == T, 0, 
                                                             length(unlist(strsplit(Scores_nodes_and_edges$Ntwrk.path3_.hits[i], ", "))))
  }
  
  
  ############################## Network Hits Total                                                 #here a counter is added for how many "hits" that are in the selected groups it's predicted to interact with.
  Scores_nodes_and_edges <- Scores_nodes_and_edges %>%
    mutate(Total_Path_Hits.net.count = path1_hits.net.count + path3_hits.net.count + path2_hits.net.count)
  
  
  ###write file                                                                                   #Final File is created
  
  #Organize column order
  Scores_nodes_and_edges <- Scores_nodes_and_edges[, c("EntrezID", "GeneSymbol", "GeneMappingID", "ConfidenceCategory"
                                                       , "Group", "Pathway"
                                                       , "Allnet.count", "Ntwrk.all"
                                                       ,"path1_hits.net.count" ,"Ntwrk.path1_.hits"
                                                       ,"path2_hits.net.count" ,"Ntwrk.path2_.hits"
                                                       ,"path3_hits.net.count" ,"Ntwrk.path3_.hits"
                                                       ,"Total_Path_Hits.net.count"
  )]
  

  names(Scores_nodes_and_edges)[names(Scores_nodes_and_edges) == "Ntwrk.path1_.hits"] <- paste0("Ntwrk.", path1_name)
  names(Scores_nodes_and_edges)[names(Scores_nodes_and_edges) == "path1_hits.net.count"] <- paste0("NtwrkCount.", path1_name)
  names(Scores_nodes_and_edges)[names(Scores_nodes_and_edges) == "Ntwrk.path2_.hits"] <- paste0("Ntwrk.", path2_name)
  names(Scores_nodes_and_edges)[names(Scores_nodes_and_edges) == "path2_hits.net.count"] <- paste0("NtwrkCount.", path2_name)
  names(Scores_nodes_and_edges)[names(Scores_nodes_and_edges) == "Ntwrk.path3_.hits"] <- paste0("Ntwrk.", path3_name)
  names(Scores_nodes_and_edges)[names(Scores_nodes_and_edges) == "path3_hits.net.count"] <- paste0("NtwrkCount.", path3_name)
  
  #Character strings of pathways names removing spaces and non-alpha numeric chracters
  names.SelectedPathways_3 <- paste0(gsub("[[:space:] ]", "_", gsub("[^[:alnum:] ]", "", path1_name)), "_",
                              gsub("[[:space:] ]", "_", gsub("[^[:alnum:] ]", "", path2_name)), "_",
                              gsub("[[:space:] ]", "_", gsub("[^[:alnum:] ]", "", path3_name)))
  
  names.SelectedPathways_2 <- paste0(gsub("[[:space:] ]", "_", gsub("[^[:alnum:] ]", "", path1_name)), "_",
                                        gsub("[[:space:] ]", "_", gsub("[^[:alnum:] ]", "", path2_name)))
  
  names.SelectedPathways_1 <- paste0(gsub("[[:space:] ]", "_", gsub("[^[:alnum:] ]", "", path1_name)))
  
  if(length(selectedRows) == 3){
    RankingFileName.output <- paste0("SIGNALsort_" , inputFilePrefix, "_", names.SelectedPathways_3, ".csv")
  }
  if(length(selectedRows) == 2){
    RankingFileName.output <- paste0("SIGNALsort_", inputFilePrefix, "_", names.SelectedPathways_2, ".csv")
  }
  if(length(selectedRows) == 1){
    RankingFileName.output <- paste0("SIGNALsort_", inputFilePrefix, "_", names.SelectedPathways_1, ".csv")
  }

  Scores_nodes_and_edges <<- Scores_nodes_and_edges
  #message(SIGNAL.output, "**")
  #setwd(downloadDir)
  setwd('SIGNALfilesToDownload')
  write.csv(Scores_nodes_and_edges, RankingFileName.output)
  
  ############################################################################### Add visualization ##############################################################################
  
  #############**************************************************################
  ###############################################################################
  #                 Hirachical Edge Bundling
  ###############################################################################
  
  #Set up dataframe for groupings (Loc)                                          #Assigning a number to each group (this will enable the grouping later)
  NodeInfo$Loc <- 4
  NodeInfo$Loc[NodeInfo$EntrezID %in% path3_hits.matrix] <-3
  NodeInfo$Loc[NodeInfo$EntrezID %in% path2_hits.matrix] <-2
  NodeInfo$Loc[NodeInfo$EntrezID %in% path1_hits.matrix] <-1
  
  #Set up dataframe for IDs                                                      #now creating a name in the format of groupNumber.geneSymbol
  NodeInfo$ID <- paste(NodeInfo$Loc, NodeInfo$GeneSymbol, sep = ".")
  names(NodeInfo)[names(NodeInfo)== "GeneSymbol"] <- "key"
  
  colnames(NodeInfo)[names(NodeInfo)== "ConfidenceCategory"] = 'Confidence'
  
  #Move ID column first
  NodeInfo = NodeInfo[,c('ID', 'GeneMappingID', 'key', 'Loc', 'Confidence', 'Pathway')]
  
  #Set up rel file                                                              #The Hirarchical edge bundle package needs to dataframes, a NodeInfor with information about the nodes and a "rel" file about the relationships to be highilighted.
  rel.source <- merge(EdgeInfo, NodeInfo[, c("GeneMappingID", "ID", "Loc")], by.x = "source", by.y = "GeneMappingID", all.x = TRUE)      #To create the rel file the "EdgeInfo" file is combined with teh NodeInfo information
  names(rel.source)[names(rel.source)=="ID"] <- "source.ID"
  names(rel.source)[names(rel.source)=="Loc"] <- "Loc.source"
  
  rel.target <- merge(rel.source, NodeInfo[, c("GeneMappingID", "ID", "Loc")], by.x = "target", by.y = "GeneMappingID", all.x = TRUE)
  names(rel.target)[names(rel.target)=="ID"] <- "target.ID"
  names(rel.target)[names(rel.target)=="Loc"] <- "Loc.target"
  
  #Remove non hits                                                   #There are more connections than we want to visualize so here some connections are being removed to simplify
  rel.target.filter <- filter(rel.target, Loc.source !=  Loc.target) #Here connections within the same group are ignored (assuming that we are only interested in intergroup connections)
  rel.7 <- filter(rel.target, Loc.source != 4 & Loc.target != 4 &    #Here connections between Novel genes and other Novels genes are pulled out to be added back in later.
                    Loc.source != 3 & Loc.target != 3 &
                    Loc.source != 2 & Loc.target != 2 &
                    Loc.source != 1 & Loc.target != 1 )
  
  # Netgraph with 2nd dimension of connections
  #rel2.7 <- filter(rel.target, Loc.source == 4 & Loc.target == 4)    #Here connections between Novel genes and other Novels genes are pulled out to be added back in later.
  
  degree2.filter <- function(rel){
    markers = c()
    new.rel = filter(rel, Loc.source == 4 & Loc.target == 4)
    for(i in 1:nrow(new.rel)){
      r = new.rel[i,]
      st.filter = filter(rel, source.ID == r$source.ID | target.ID == r$target.ID)
      if(any(st.filter$Loc.target!=4) || any(st.filter$Loc.source!=4)){
        markers = append(markers, i)
      }
    }
    return(new.rel[markers,])
  }
  
  rel2.7 = degree2.filter(rel.target) 
  
  rel.target <- rbind(rel.target.filter, rel.7)                      #Intra-connections of Novel genes are added to list of inter-group connections
  
  # For netgraph with 2nd dimension of connections
  rel2.target <- rbind(rel.target.filter, rel2.7)                      #Intra-connections of Novel genes are added to list of inter-group connections
  
  
  # Fix directionality of connection for members of group seven    #Hirarchical edge bundling colors the interactions based on the source so here the columns are switched to get the result wanted (shoudl Novel-group interactions be the color of the group or the color of the "novel" gene category)
  rel.target.filter <- filter(rel.target, Loc.target != 4)
  # For netgraph with 2nd dimension of connections
  rel2.target.filter <- filter(rel2.target, Loc.target != 4)
  rel.7 <- filter(rel.target, Loc.target == 4)
  # For netgraph with 2nd dimension of connections
  rel2.7 <- filter(rel2.target, Loc.target == 4)
  
  #Switchnames for 1st dimension graph only
  names(rel.7)[names(rel.7)=="target.ID"] <- "target.ID2"
  names(rel.7)[names(rel.7)=="source.ID"] <- "source.ID2"
  names(rel.7)[names(rel.7)=="target"] <- "target2"
  names(rel.7)[names(rel.7)=="source"] <- "source2"
  names(rel.7)[names(rel.7)=="target.ID2"] <- "source.ID"
  names(rel.7)[names(rel.7)=="source.ID2"] <- "target.ID"
  names(rel.7)[names(rel.7)=="target2"] <- "source"
  names(rel.7)[names(rel.7)=="source2"] <- "target"
  
  #Switchnames for 2nd dimension graph
  names(rel2.7)[names(rel2.7)=="target.ID"] <- "target.ID2"
  names(rel2.7)[names(rel2.7)=="source.ID"] <- "source.ID2"
  names(rel2.7)[names(rel2.7)=="target"] <- "target2"
  names(rel2.7)[names(rel2.7)=="source"] <- "source2"
  names(rel2.7)[names(rel2.7)=="target.ID2"] <- "source.ID"
  names(rel2.7)[names(rel2.7)=="source.ID2"] <- "target.ID"
  names(rel2.7)[names(rel2.7)=="target2"] <- "source"
  names(rel2.7)[names(rel2.7)=="source2"] <- "target"
  
  rel.target <- rbind(rel.target.filter, rel.7)
  rel2.target <- rbind(rel2.target.filter, rel2.7)
  
  #Flip columns to get pathway colors as links
  names(rel.target)[names(rel.target)=="target.ID"] <- "target.ID2"
  names(rel.target)[names(rel.target)=="source.ID"] <- "source.ID2"
  names(rel.target)[names(rel.target)=="target"] <- "target2"
  names(rel.target)[names(rel.target)=="source"] <- "source2"
  names(rel.target)[names(rel.target)=="target.ID2"] <- "source.ID"
  names(rel.target)[names(rel.target)=="source.ID2"] <- "target.ID"
  names(rel.target)[names(rel.target)=="target2"] <- "source"
  names(rel.target)[names(rel.target)=="source2"] <- "target"
  
  rel <- rel.target[, c("source.ID", "target.ID")]
  names(rel)[names(rel)=="source.ID"] <- "V1"
  names(rel)[names(rel)=="target.ID"] <- "V2"
  rel$weights = rel.target$weights
  rel$datasource = rel.target$datasource
  
  #Flip columns to get pathway colors as links for 2nd dimension graph
  names(rel2.target)[names(rel2.target)=="target.ID"] <- "target.ID2"
  names(rel2.target)[names(rel2.target)=="source.ID"] <- "source.ID2"
  names(rel2.target)[names(rel2.target)=="target"] <- "target2"
  names(rel2.target)[names(rel2.target)=="source"] <- "source2"
  names(rel2.target)[names(rel2.target)=="target.ID2"] <- "source.ID"
  names(rel2.target)[names(rel2.target)=="source.ID2"] <- "target.ID"
  names(rel2.target)[names(rel2.target)=="target2"] <- "source"
  names(rel2.target)[names(rel2.target)=="source2"] <- "target"
  
  rel2 <- rel2.target[, c("source.ID", "target.ID")]
  names(rel2)[names(rel2)=="source.ID"] <- "V1"
  names(rel2)[names(rel2)=="target.ID"] <- "V2"
  rel2$weights = rel2.target$weights
  rel2$datasource = rel2.target$datasource
  
  # Remove nodes that do not have connection to the selected pathways
  rel.V1.matrix <- as.matrix((unique(rel$V1)))
  rel.V2.matrix <- as.matrix((unique(rel$V2)))
  rel.genes.matrix <- as.matrix(unique(rbind(rel.V1.matrix, rel.V2.matrix)))
  
  #NodeInfo <- subset(NodeInfo, !is.na(key))
  
  NodeInfo2 <<- NodeInfo
  NodeInfo1 <<- filter(NodeInfo, Loc != 4 | ID %in% rel.genes.matrix)
  
  #Generate the graph
  g <<- graph.data.frame(rel, directed=T, vertices=NodeInfo1)
  g2 <<- graph.data.frame(rel2, directed=T, vertices=NodeInfo2)
  
  # Check to make sure the generated graph is full
  if(length(E(g))==0 | length(V(g))==0){
    showModal(modalDialog(title="Warning:", HTML("<h3><font color=red>Criteria produced empty network. Session will restart.</font><h3>"),
                          easyClose = FALSE))
    Sys.sleep(5)
    session$reload()
  }
  
  clr <- as.factor(V(g)$Loc)
  clr2 <- as.factor(V(g2)$Loc)
  
  
  if(length(selectedRows) == 3){
    levels(clr) <- c("red", "darkblue", "saddlebrown", "green")  #Four colors are chosen since there are four groups including the other SIGNAL hit genes
    levels(clr2) <- c("red", "darkblue", "saddlebrown", "green")  #Four colors are chosen since there are four groups including the other SIGNAL hit genes
  }
  if(length(selectedRows) == 2){
    levels(clr) <- c("red", "darkblue", "green")  #Three colors are chosen since there are three groups
    levels(clr2) <- c("red", "darkblue", "green")  #Three colors are chosen since there are three groups
  }
  if(length(selectedRows) == 1){
    levels(clr) <- c("red", "green")  #Two colors are chosen since there are two groups
    levels(clr2) <- c("red", "green")  #Two colors are chosen since there are two groups
  }
  
  V(g)$color <- as.character(clr)
  V(g)$size = degree(g)*5
  
  V(g2)$color <- as.character(clr2)
  V(g2)$size = degree(g2)*5
  
  # igraph static plot
  #plot(g, layout = layout.circle, vertex.label=NA)
  
  #Chimera1 <<- edgebundleR::edgebundle(g, tension = 0.8, fontsize = 8)       
  #Chimera2 <<- edgebundleR::edgebundle(g2, tension = 0.8, fontsize = 3)
  
  # Create 1st dimension networkD3 object
  g11 = g
  g11_wc <- cluster_walktrap(g11)
  g11_members <- membership(g11_wc)
  
  # Convert to object suitable for networkD3
  g11_d3 <<- igraph_to_networkD3(g11, group = g11_members)
  g11_vis <<- toVisNetworkData(g11)
  
  #json_data <- rbind(names(g), sapply(g, as.character))
  #json_1 <- jsonlite::toJSON(g11_vis$nodes, 'rows')
  #json_1 <- Chimera1[[1]][1]$json_real
  dimNames = c(path1_name, path2_name, path3_name)
  json_1df <<- config_df(g11_vis$nodes, g11_vis$edges, dimNames)
  json_1 = jsonlite::toJSON(json_1df, 'columns')
  session$sendCustomMessage(type="jsondata1",json_1)
  #session$sendCustomMessage(type="jsondata",json_2)
  
  # Create 2nd dimension networkD3 object
  g22 = g2
  g22_wc <- cluster_walktrap(g22)
  g22_members <- membership(g22_wc)
  
  # Convert to object suitable for networkD3
  g22_d3 <<- igraph_to_networkD3(g22, group = g22_members)
  g22_vis <<- toVisNetworkData(g22)
  
  json_2df <<- config_df(g22_vis$nodes, g22_vis$edges, dimNames)
  json_2 <- jsonlite::toJSON(json_2df, 'columns')
  session$sendCustomMessage(type="jsondata2",json_2)
  
  # Add a legend box on the html page
  # if(length(selectedRows) == 3){
  #   graphLegend <<- sprintf('
  #                           <div id="htmlwidget_container">
  #                           <form style="width: 360px; margin: 0 auto; color: grey;">
  #                           <fieldset>
  #                           <legend>Network Graph Colors:</legend>
  #                           <font color="red" face="courier"><b>&nbsp;&nbsp;Red:</b></font><font size="-1" color="red"> %s</font><br>
  #                           <font color="darkblue" face="courier"><b>&nbsp;Blue:</b></font><font size="-1" color="darkblue"> %s</font><br>
  #                           <font color="saddlebrown" face="courier"><b>Brown:</b></font><font size="-1"color="saddlebrown"> %s</font><br>
  #                           <font color="green" face="courier"><b>Green:</b></font><font size="-1" color="green"> %s</font><br>
  #                           </fieldset>
  #                           </form>',
  #                           path1_name, path2_name, path3_name, "other SIGNAL hit genes")
  # }
  # if(length(selectedRows) == 2){
  #   graphLegend <<- sprintf('
  #                           <div id="htmlwidget_container">
  #                           <form style="width: 360px; margin: 0 auto; color: grey">
  #                           <fieldset>
  #                           <legend>Network Graph Colors:</legend>
  #                           <font color="red" face="courier"><b>&nbsp;&nbsp;Red:</b></font><font size="-1" color="red"> %s</font><br>
  #                           <font color="darkblue" face="courier"><b>&nbsp;Blue:</b></font><font size="-1" color="darkblue"> %s</font><br>
  #                           <font color="green" face="courier"><b>Green:</b></font><font size="-1" color="green"> %s</font><br>
  #                           </fieldset>
  #                           </form>',
  #                           path1_name, path2_name, "other SIGNAL hit genes")
  # }
  # if(length(selectedRows) == 1){
  #   graphLegend <<- sprintf('
  #                           <div id="htmlwidget_container">
  #                           <form style="width: 360px; margin: 0 auto; color: grey;">
  #                           <fieldset>
  #                           <legend>Network Graph Colors:</legend>
  #                           <font color="red" face="courier"><b>&nbsp;&nbsp;Red:</b></font><font size="-1" color="red"> %s</font><br>
  #                           <font color="green" face="courier"><b>Green:</b></font><font size="-1" color="green"> %s</font><br>
  #                           </fieldset>
  #                           </form>',
  #                           path1_name, "other SIGNAL hit genes")
  # }
  
  
  
  #Places (2) where plot will be saved to
  #setwd(SIGNAL.output)    
  #saveEdgebundle(Chimera1, "Chimera_STRINGHi_against_selectedPathways_1st.hits.html")
  #saveEdgebundle(Chimera2, "Chimera_STRINGHi_against_selectedPathways_2nd.hits.html")
  #Creating name for Chimera plots, now called PathNet
  if(length(selectedRows) == 3){
    PathNetName.output <<- paste0("PathNet_", inputFilePrefix, "_", names.SelectedPathways_3)
  }
  if(length(selectedRows) == 2){
    PathNetName.output <<- paste0("PathNet_", inputFilePrefix, "_", names.SelectedPathways_2)
  }
  if(length(selectedRows) == 1){
    PathNetName.output <<- paste0("PathNet_", inputFilePrefix, "_", names.SelectedPathways_1)
  }
  
  # commenting out code to save network .html files
  
  # if(grepl('shiny', outputDir)){
  #   saveEdgebundle(Chimera1, file = paste0("/srv/shiny-server/", PathNetName.output, "1Degree.html"))
  #   saveEdgebundle(Chimera2, file = paste0("/srv/shiny-server/", PathNetName.output, "2Degree.html"))
  # }else{
  #   #saveEdgebundle(Chimera1,file = paste0("/Library/WebServer/Documents/", PathNetName.output, "1Degree.html"))
  #   saveEdgebundle(Chimera1,file = paste0(PathNetName.output, "1Degree.html"))
  #   #saveEdgebundle(Chimera2,file = paste0("/Library/WebServer/Documents/", PathNetName.output, "1Degree.html"))
  #   saveEdgebundle(Chimera2,file = paste0(PathNetName.output, "1Degree.html"))
  # }
  
  
  return(TRUE)
}
