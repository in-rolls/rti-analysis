to_date <- function(x) as.Date(dplyr::na_if(x, ""))

# Government function, coded from department and office names ----
code_function <- function(x) {
  x <- stringr::str_to_lower(x)
  dplyr::case_when(
    stringr::str_detect(x, "industrial safety|scheduled caste|scheduled tribe") ~ "Welfare, labour and food",
    stringr::str_detect(x, "transco|genco|kptcl|escom|electricity") ~ "Infrastructure and utilities",
    stringr::str_detect(x, paste0(
      "school|education|college|university|mahavidyalaya|institute of technology|",
      "polytechnic|\\bdiet\\b|public instruction|training institute|\\bbeo\\b|",
      "\\bdeo\\b|\\bddpi\\b|intermediate"
    )) ~ "Education",
    stringr::str_detect(x, paste0(
      "health|hospital|medical|ayush|ayurved|ismh|chikitsalaya|vaidya|aids ",
      "control|drugs control"
    )) ~ "Health",
    stringr::str_detect(x, paste0(
      "police|\\bhome\\b|prison|jail|\\bfire\\b|court|judge|\\blaw\\b|legal|",
      "lokayukta|excise|prohibition|vigilance"
    )) ~ "Police, justice and excise",
    stringr::str_detect(x, paste0(
      "panchayat|rural|zilla|\\brdpr|municipal|\\bdudc\\b|urban|housing|slum|",
      "town|city corporation|praja parishad|mandal parishad|development ",
      "authority|planning authority|\\bzp\\b"
    )) ~ "Local government and housing",
    stringr::str_detect(x, paste0(
      "revenue|tahsil|tehsil|collector|registration|stamps|\\bland|survey|",
      "\\bddlr\\b|\\bdr\\b|\\bsslr\\b|commercial tax|deputy commissioner|",
      "divisional commissioner|disaster"
    )) ~ "Revenue, land and registration",
    stringr::str_detect(x, paste0(
      "agri|animal|husba|veterinary|fisher|dairy|horticulture|sericulture|",
      "cooperat|co-operat|forest|environment|climate|pollution|mines|geology|",
      "natural resources|marketing|deputy registrar"
    )) ~ paste0(
      "Agriculture, cooperatives and environment"
    ),
    stringr::str_detect(x, paste0(
      "\\bpwd\\b|public works|roads|highway|irrigation|water|energy|\\bpower\\b|",
      "transport|\\brtc\\b|tgsrtc|ksrtc|\\brto\\b|minor ports|\\bcad\\b|sewerage"
    )) ~ "Infrastructure and utilities",
    stringr::str_detect(x, paste0(
      "welfare|tribal|women|child|\\bicds\\b|backward|minorit|disab|labour|",
      "\\blabor\\b|employment|skill|social|\\bsc\\b|\\bsc\\.|\\bobc\\b|\\bfcs\\b|",
      "food|civil supplies|consumer"
    )) ~ "Welfare, labour and food",
    TRUE ~ "Finance, industry and other"
  )
}
