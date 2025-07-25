# Author: Niklas Nett
# Created: 2025-04-12
# Last updated: 2025-07-21

# Purpose: Calculate Shannon diversity indices for each microbial community (Bacteria, Protists, Fungi, Metazoa)
#          Visualize alpha diversity trends using a faceted ggplot with LOESS smoothing and grouped legends.
#          Save Shannon diversity indices in separate tables.
# Input:   - filtered_combined_table_PR2_and_SILVA.csv (genus-level merged count table with metadata)
# Output:  - Shannon_Facette_plot.svg                    
#          - ShannonTable_<Community>.csv

# Load packages
library(dplyr)
library(tidyr)
library(vegan)
library(ggplot2)

# Define directory
setwd("/Users/macniklas/Desktop/MA.ster_2.025/")

# Read input file (merged table)
data <- read.csv("filtered_combined_table_PR2_and_SILVA.csv", header = TRUE, stringsAsFactors = FALSE)

# rename plants
data <- data %>%
  mutate(PLANT = recode(PLANT, 
                        "Rensningsanlaeg Damhusaaen"                    = "Copenhagen_RD",
                        "Rensningsanlaeg Avedoere"                      = "Copenhagen_RA",
                        "Rensningsanlaeg Lynetten"                      = "Copenhagen_RL",
                        "Dokhaven"                                      = "Rotterdam",
                        "ATO2 Wastewater Treatment Plant"               = "Rome",
                        "Gruppo HERA"                                   = "Bologna",
                        "Budapesti Kozponti Szennyviztisztito Telep"    = "Budapest"))


# set order of plants (north to south)
plant_order <- c("Copenhagen_RL", "Copenhagen_RD", "Copenhagen_RA", "Rotterdam", "Budapest", "Bologna", "Rome")

# create shannon function (to run shannon calculations for each Microbial Community)
shannon_function <- function(df) {
  df <- df %>%                         
    mutate(Date = as.Date(COLLECTION_DATE)) %>%  # define COLLECTION_DATE as Date
    group_by(PLANT, Date, Genus, AccessionID) %>%  # filter out each Genus per Sample (Plant & Date) ...
    summarise(abundance = sum(NumberOfReads, na.rm = TRUE), # ... & aggregate NumberofReads
              .groups   = "drop") %>%              
    pivot_wider(                          # transform into wide format (for matrix)
      names_from  = Genus,
      values_from = abundance,
      values_fill = 0
    )
  
  counts <- df %>%                       # build matrix
    select(-PLANT, -Date, -AccessionID) %>% 
    as.matrix()
  
  shannon_values <- vegan::diversity(counts, index = "shannon") # calculate shannon values
  
  shannon_df <- df %>%                   # transfer values into data frame
    select(PLANT, Date, AccessionID) %>% 
    mutate(ShannonIndex = shannon_values)
  
  return(shannon_df)
}

# filter out data for each microbial community
data_metazoa  <- data %>% filter(Microbial_Community == "Metazoa")
data_bacteria <- data %>% filter(Microbial_Community == "Bacteria")
data_fungi    <- data %>% filter(Microbial_Community == "Fungi")
data_protists <- data %>% filter(Microbial_Community == "Protists")

# run shannon function for each Microbial Community
shannon_metazoa  <- shannon_function(data_metazoa) %>%
  mutate(Domain = "Metazoa")
shannon_bacteria <- shannon_function(data_bacteria) %>%
  mutate(Domain = "Bacteria")
shannon_fungi    <- shannon_function(data_fungi) %>%
  mutate(Domain = "Fungi")
shannon_protists <- shannon_function(data_protists) %>%
  mutate(Domain = "Protists")

# Combine all shannon results from all Communities & sort by Date
shannon_all <- bind_rows(shannon_metazoa, shannon_bacteria, shannon_fungi,  shannon_protists) %>% 
  arrange(PLANT, Domain, Date)            

# set colors for Microbial Communities
community_colors <- c(
  "Metazoa"   = "#F8766D",  
  "Bacteria"  = "#00BA38",  
  "Fungi"     = "#619CFF",  
  "Protists"  = "#C77CFF"   
)

# set different linetypes for each Microbial Communities & corresponding LOESS
line_type <- c(
  "Metazoa"   = "solid",
  "Bacteria"  = "dotdash",
  "Fungi"     = "twodash",
  "Protists"  = "dotted"
)

# set order of plants --> later from north (left) to south (right)
shannon_all$PLANT <- factor(shannon_all$PLANT, levels = plant_order)

# create facet shannon plot 
p <- ggplot(shannon_all, aes(
  x = Date,
  y = ShannonIndex,
  color = Domain,        
  group = interaction(PLANT, Domain),
  linetype = Domain       
)) +
  geom_line(linewidth = 0.3) +
  geom_point(size = 0.1) +
  geom_smooth(method = "loess", se = FALSE,linewidth = 0.3 , color = "black") + # Add LOESS-smoothed trend line for each microbial community
  scale_color_manual(values = community_colors) +
  scale_linetype_manual(values = line_type) +
  facet_wrap(~PLANT, nrow = 1, scales = "free_x") +
  scale_x_date(date_breaks = "1 month", labels = NULL) +
  coord_cartesian(expand = FALSE) +
  scale_y_continuous(limits = c(0, 5.5)) +
  labs(
    x = NULL,  
    y = "Shannon Index",
    title = NULL,
    color = "Domain",
    linetype = "Domain"
  ) +
  theme_minimal(base_family = "Helvetica Neue", base_size = 7) +
  theme(
    axis.line.x       = element_line(colour = "gray40", linewidth = 0.2),
    axis.ticks.x      = element_line(colour = "gray40", linewidth = 0.2),
    axis.ticks.length = unit(2, "pt"),  
    axis.text.y      = element_text(size = 6.5),
    axis.title.x     = element_text(),
    axis.title.y     = element_text(size = 8, margin = margin(r = 3), colour = "gray20"),
    strip.text       = element_text(face = "bold", size = 8),
    strip.background = element_rect(fill = "gray90", color = NA),
    legend.position = "bottom",
    legend.title     = element_text(size = 8, face = "bold"),
    legend.text      = element_text(size = 8),    
    legend.key.size  = unit(1.2, "lines"),          
    legend.margin      = margin(t = 3),
    legend.spacing.x = unit(12, "pt"),
    panel.spacing.x = unit(3, "pt")
  ) +
  # create legends --> one for COLOR and one for LOESS
  guides(
    colour = guide_legend(                      
      title         = "Microbial Community (Datapoints)",
      order         = 1,
      title.position = "top",
      nrow          = 1,
      byrow         = TRUE,
      override.aes  = list(size = 1, linewidth = 0.8)
    ),
    linetype = guide_legend(                   
      title         = "Microbial Community (LOESS)",
      order         = 2,
      title.position = "top",
      nrow          = 1,
      byrow         = TRUE,
      override.aes  = list(size = 2, linewidth = 0.8)
    )
  )

# save plot as SVG
ggsave(
  "Shannon_Facette_plot.svg",
  plot   = p,                 
  device = "svg",
  width  = 190,               
  height = 35.9,              
  units  = "mm"
)

# save shannon results (values) into csv (for later analysis)
for (community in unique(shannon_all$Domain)) {
  
  shannon_table <- shannon_all %>%
    filter(Domain == community) %>%
    mutate(PLANT = factor(PLANT, levels = plant_order)) %>%
    arrange(PLANT, Date) %>%
    mutate(Date = format(Date, "%m-%d-%Y")) %>%
    select(AccessionID, PLANT, Date, ShannonIndex)
  
  outputfile <- paste0("ShannonTable_", community, ".csv")
  write.csv(shannon_table, outputfile, row.names = FALSE)
  cat("Saved:", outputfile, "\n")
}
