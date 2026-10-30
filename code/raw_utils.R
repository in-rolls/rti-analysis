# AMAR & SOOD - RTI FIRST-CUT ANALYSIS (2026)
## FILE: raw_utils.R
### Pure functions for reading the original inputs: classify an email, pull out its fields, read
### RA sheet values, and match messages to applications. Tested in tests/testthat/test-raw-utils.R.
# ----
# Originals ----
ORIGINAL_FOLDERS <- c(
  "email_tracker/raw", "email_tracker/attachments", "rti responses",
  "Filed_RTI"
)

## Paths can hold inbox and filer names, so the manifest in git stores a hash of each path
path_hash <- function(path) {
  vapply(path, digest::digest, "", algo = "md5", serialize = FALSE, USE.NAMES = FALSE)
}

list_originals <- function(raw_root, folder) {
  files <- list.files(file.path(raw_root, folder), recursive = TRUE, full.names = TRUE)
  rel <- str_remove(files, fixed(paste0(raw_root, "/")))
  tibble(folder = folder, path = rel, path_md5 = path_hash(rel), bytes = file.size(files))
}

## The files in a folder that the manifest pins, and a stop if any pinned file has gone
pinned_originals <- function(raw_root, folder, manifest) {
  pins <- manifest |> filter(folder == !!folder)
  found <- list_originals(raw_root, folder) |>
    select(path, path_md5) |>
    inner_join(select(pins, path_md5, md5), by = "path_md5")
  if (nrow(found) != nrow(pins)) stop("Originals missing from ", folder)
  found
}

## A public file pinned to a commit. It is downloaded once, and a different checksum is an error,
## never a silent substitution.
fetch_pinned <- function(pin, dest_dir) {
  dest <- file.path(dest_dir, paste0(pin$ref, "_", basename(pin$path)))
  if (!file.exists(dest)) {
    dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
    url <- sprintf("https://raw.githubusercontent.com/%s/%s/%s", pin$repo, pin$ref, pin$path)
    utils::download.file(url, dest, quiet = TRUE, mode = "wb")
  }
  if (unname(tools::md5sum(dest)) != pin$md5) {
    stop("Pinned file does not match its checksum: ", pin$repo, "/", pin$path)
  }
  dest
}

# Portal senders ----
## Registration numbers decide the application; the sender only says which template to expect.
PORTAL_SENDERS <- c(
  "rtisupport@tn.gov.in" = "TN", "rtionline-kar@nic.in" = "KA", "tsrtinoreply@gmail.com" = "TG",
  "noreply-rtimh@mah.gov.in" = "MH", "noreply-dopt@gov.in" = "CENTRAL"
)
PORTAL_DOMAINS <- c(".gov.in", ".nic.in")
SYSTEM_DOMAINS <- c("google.com", "accounts.google.com", "googlemail.com")

# Patterns ----
## No word boundaries at the ends: portal text glues the next label on ("/60009Name:").
## Office codes can hold an ampersand (DD&DC, HG&CD), written &amp; in some mail
REG_RE <- paste0(
  "(?<![A-Z&])([A-Z&]{4,9}|[A-Z]{2}&amp;[A-Z]{2})\\s*/\\s*([RA])\\s*/\\s*(20\\d\\d)\\s*/\\s*",
  "(\\d{4,6})(?!\\d)"
)
TG_REG_RE <- "\\bTGRTI/APP/[A-Z&]+/\\d{2}/\\d{2}/\\d{2}/[A-Z]+/\\d+\\b"
EMAIL_RE <- "[\\w.+-]+@[\\w-]+(?:\\.[\\w-]+)+"
DATE_RE <- "\\b(\\d{1,2})[./-](\\d{1,2})[./-](20\\d\\d)\\b"
APP_RE <- "^(TN|TG|KA|DL|MH)-\\d{3,4}$"
FEE_RE <- regex(paste0(
  "\\bfees?\\b|additional (?:fee|cost|amount)|postal order|\\bIPO\\b|demand draft|",
  "\\bD\\.?D\\.?\\b|challan|remit|per page|photocopy charges"
), ignore_case = TRUE)
## An office writing about an RTI, in English, Marathi, Hindi, Kannada or Tamil
RTI_WORDS_RE <- paste0(
  "\\brti\\b|right to information|information sought|petition|",
  "\u092e\u093e\u0939\u093f\u0924\u0940(?:\u091a\u093e)? \u0905\u0927\u093f\u0915\u093e\u0930|",
  "\u0938\u0942\u091a\u0928\u093e \u0915\u093e \u0905\u0927\u093f\u0915\u093e\u0930|",
  "\u0cae\u0cbe\u0cb9\u0cbf\u0ca4\u0cbf \u0cb9\u0c95\u0ccd\u0c95\u0cc1|",
  "\u0ba4\u0b95\u0bb5\u0bb2\u0bcd \u0b85\u0bb1\u0bbf\u0baf\u0bc1\u0bae\u0bcd ",
  "\u0b89\u0bb0\u0bbf\u0bae\u0bc8"
)

# Text helpers ----
## Undo the portals' non-breaking-space damage and normalise whitespace within lines
clean_text <- function(x) {
  x <- ifelse(is.null(x) || is.na(x), "", x)
  x <- str_replace_all(x, "\r\n?", "\n")
  x <- str_replace_all(x, "\u00c2\u00a0", " ")
  x <- str_replace_all(x, "\u00a0", " ")
  x <- str_replace_all(x, "\u00c2", " ")
  str_replace_all(x, "[ \t]+", " ")
}

email_sender <- function(from) {
  from <- ifelse(is.null(from) || is.na(from), "", from)
  m <- str_match(from, "<([^>]+)>")[, 2]
  str_to_lower(str_trim(ifelse(is.na(m), from, m)))
}

## Prefer the HTML rendering, where cell separators survive; else plain text
email_body <- function(rec) {
  h <- clean_text(rec$body_html_text)
  p <- clean_text(rec$body_text)
  if (nchar(h) >= nchar(p) * 0.8 && nzchar(str_trim(h))) h else p
}

reg_numbers <- function(text) {
  if (is.null(text) || is.na(text) || !nzchar(text)) {
    return(character())
  }
  m <- str_match_all(text, REG_RE)[[1]]
  if (nrow(m) == 0) {
    return(character())
  }
  codes <- str_replace_all(m[, 2], fixed("&amp;"), "&")
  unique(paste(codes, m[, 3], m[, 4], m[, 5], sep = "/"))
}

## A registration number as typed into a sheet: tabs, entities, spaces, case
norm_reg <- function(x) {
  x <- ifelse(is.null(x) || is.na(x), "", x)
  x <- str_replace_all(x, fixed("&#9;"), " ")
  x <- str_replace_all(x, fixed("&amp;"), "&")
  x <- str_replace_all(str_to_upper(str_trim(x)), "\\s+", "")
  found <- reg_numbers(x)
  if (length(found) > 0) {
    return(found[1])
  }
  tg <- str_extract(x, TG_REG_RE)
  if (is.na(tg)) x else tg
}

## A real registration number has a digit and a slash; RAs sometimes type a note in that cell
is_real_reg <- function(x) str_detect(coalesce(x, ""), "\\d") & str_detect(coalesce(x, ""), "/")

## PIO addresses as typed into the portal: "x @ gmail.com", "x@.domain.net"
fix_email <- function(x) {
  x <- str_replace_all(str_trim(coalesce(x, "")), "\\s*@\\s*", "@")
  x <- str_replace_all(x, "\\s*\\.\\s*", ".")
  x <- str_replace_all(x, fixed("@."), "@")
  m <- str_extract(x, EMAIL_RE)
  if (is.na(m)) "" else str_remove(str_to_lower(m), "\\.$")
}

email_field <- function(text, label, value = "(.+?)", stop = "(?=\\s*(?:\\||\\n|$))") {
  pattern <- regex(paste0(label, "\\s*[:|]*\\s*[:|]?\\s*", value, stop), ignore_case = TRUE)
  m <- str_match(text, pattern)[, 2]
  if (is.na(m)) "" else str_remove_all(str_remove_all(m, "^[ |:-]+"), "[ |:-]+$")
}

parse_ack <- function(text) {
  nxt <- paste0(
    "(?=\\s*(?:\\||\\n|Date of Filing|Request filed with|Public Authority|Contact Details|",
    "Nodal Officer|Telephone|Email Id|Payment Details|RTI Fee|MAHA Online|Online Reference|",
    "Transaction Status|Note:|$))"
  )
  regs <- reg_numbers(text)
  authority <- email_field(text, "Request filed with", stop = nxt)
  if (!nzchar(authority)) authority <- email_field(text, "Public Authority", stop = nxt)
  list(
    reg_no = if (length(regs) > 0) regs[1] else "",
    filer_name = email_field(text, "\\bName", stop = nxt),
    filing_date = email_field(text, "Date of Filing", "(\\d{1,2}/\\d{1,2}/\\d{4})", stop = ""),
    authority = authority,
    pio_email = fix_email(email_field(text, "Email Id", stop = nxt))
  )
}

first_reg <- function(text) {
  regs <- reg_numbers(text)
  if (length(regs) > 0) regs[1] else ""
}

# Classify one message ----
## Returns kind, portal state and the fields that kind carries. Anything unrecognised is kept as
## pio_email or other rather than dropped.
classify_email <- function(rec) {
  from <- email_sender(rec$from)
  subject <- clean_text(rec$subject)
  s <- str_to_lower(subject)
  text <- email_body(rec)
  labels <- unlist(rec$labels)
  domain <- str_extract(from, "[^@]*$")
  state <- if (from %in% names(PORTAL_SENDERS)) unname(PORTAL_SENDERS[from]) else ""
  out <- function(kind, st = state, ...) list(kind = kind, state = st, fields = list(...))
  has_system_domain <- any(endsWith(from, SYSTEM_DOMAINS)) || domain %in% SYSTEM_DOMAINS
  lead <- str_sub(str_to_lower(text), 1, 400)

  if (!is.null(rec$error)) {
    return(out("collector_error"))
  }
  if ("SENT" %in% labels && !nzchar(state)) {
    return(out("sent_by_us", "", reg_nos = reg_numbers(paste0(subject, "\n", text))))
  }
  if (has_system_domain) {
    return(out("system", ""))
  }
  if (str_detect(s, "\\botp\\b|one time password")) {
    return(out("otp"))
  }
  if (nzchar(state) || any(endsWith(domain, PORTAL_DOMAINS))) {
    if (state == "TG" && str_detect(s, fixed("submission"))) {
      ## The Telangana mail prints "$regno" (a template bug): proof of filing and its time only
      name <- str_trim(str_match(text, "Dear\\s+([^,\\n]+)")[, 2])
      tg <- str_extract(text, TG_REG_RE)
      return(out("filing_ack_tg", "TG",
        filer_name = coalesce(name, ""), reg_no = coalesce(tg, "")
      ))
    }
    filed_mail <- str_detect(s, "filed successfully|successfully (submitted|filed)")
    if (filed_mail && !str_detect(s, fixed("appeal"))) {
      return(list(kind = "filing_ack", state = state, fields = parse_ack(text)))
    }
    if (str_detect(s, fixed("appeal")) && str_detect(s, "filed|registered")) {
      return(out("appeal_ack", reg_no = first_reg(text), reg_nos = reg_numbers(text)))
    }
    if (str_detect(s, fixed("transferred"))) {
      regs <- reg_numbers(text)
      return(out("transferred",
        reg_no = if (length(regs) > 0) regs[1] else "", new_reg_nos = regs[-1]
      ))
    }
    if (str_detect(s, fixed("returned back"))) {
      return(out("returned", reg_no = first_reg(text)))
    }
    if (str_detect(s, fixed("disposed"))) {
      return(out("disposed", reg_no = first_reg(text)))
    }
    if (str_detect(s, fixed("payment processing"))) {
      return(out("payment_pending"))
    }
    fee_pattern <- "additional (fee|payment)|fee.*(due|pay)|payment.*(due|request|required)"
    if (str_detect(paste(s, lead), fee_pattern)) {
      amount <- str_match(text, "Rs\\.?\\s*([\\d,]+(?:\\.\\d+)?)")[, 2]
      return(out("fee_demand",
        reg_no = first_reg(text), amount_inr = str_remove_all(coalesce(amount, ""), ",")
      ))
    }
    if (str_detect(s, fixed("document required"))) {
      return(out("document_required", reg_no = first_reg(text)))
    }
    if (str_detect(s, fixed("reject"))) {
      return(out("rejected", reg_no = first_reg(text)))
    }
    if (nzchar(state)) {
      return(out("portal_other", reg_nos = reg_numbers(paste0(subject, "\n", text))))
    }
    ## A government office on a .gov.in or .nic.in address writing directly falls through
  }
  mentions_rti <- str_detect(paste(s, str_sub(str_to_lower(text), 1, 600)), RTI_WORDS_RE)
  if (length(rec$attachments) > 0 || mentions_rti) {
    fee_text <- paste(subject, str_sub(text, 1, 1500))
    return(out("pio_email", "",
      reg_nos = reg_numbers(paste0(subject, "\n", text)),
      mentions_fee = str_detect(fee_text, FEE_RE)
    ))
  }
  out("other", "")
}

# RA sheet values ----
## The sheets use 2026-09-26, 28-08-2026, 28/08/2026 and "04-09-2026 20:27:58"
parse_sheet_date <- function(x) {
  x <- str_trim(coalesce(x, ""))
  iso <- str_match(x, "^(\\d{4})-(\\d{1,2})-(\\d{1,2})")
  dmy <- str_match(x, "^(\\d{1,2})[-/.](\\d{1,2})[-/.](\\d{4})")
  parts <- if (!is.na(iso[1, 1])) {
    as.integer(iso[1, 2:4])
  } else if (!is.na(dmy[1, 1])) {
    as.integer(dmy[1, c(4, 3, 2)])
  } else {
    return(list(day = as.Date(NA), at = as.POSIXct(NA)))
  }
  day <- as.Date(sprintf("%04d-%02d-%02d", parts[1], parts[2], parts[3]), format = "%Y-%m-%d")
  if (is.na(day)) {
    return(list(day = as.Date(NA), at = as.POSIXct(NA)))
  }
  rest <- str_sub(x, nchar(coalesce(iso[1, 1], dmy[1, 1])) + 1)
  tm <- str_match(rest, "(\\d{1,2}):(\\d{2})(?::(\\d{2}))?")
  at <- if (is.na(tm[1, 1])) {
    as.POSIXct(NA)
  } else {
    as.POSIXct(
      sprintf(
        "%s %s:%s:%s", day, tm[1, 2], tm[1, 3], ifelse(is.na(tm[1, 4]), "00", tm[1, 4])
      ),
      tz = "Asia/Kolkata"
    )
  }
  list(day = day, at = at)
}

# Matching helpers ----
norm_name <- function(x) {
  x <- str_replace_all(str_to_lower(coalesce(x, "")), fixed("&amp;"), "&")
  x <- str_replace_all(x, fixed("husbadry"), "husbandry")
  str_trim(str_replace_all(str_replace_all(x, "[^a-z0-9]+", " "), "\\s+", " "))
}

name_similarity <- function(a, b) {
  if (!nzchar(a) || !nzchar(b)) {
    return(0)
  }
  1 - as.numeric(utils::adist(a, b)) / max(nchar(a), nchar(b))
}

MATCH_STOP_WORDS <- str_split(paste(
  "department office officer officers district government public information application",
  "petition online reply regarding details requested under sent dated secretariat section rti",
  "the and for sir madam tamil nadu karnataka telangana maharashtra delhi from your letter reg",
  "thiru attachment kindly download please find below with regards chennai directorate director",
  "commissioner commissionerate joint deputy assistant state head headquarters main road street",
  "nagar near copy dear this that which will have been reference cited following given directed",
  "invite attention question questions answer act 2005 annual return register"
), " ")[[1]]

name_tokens <- function(x, stop_words = MATCH_STOP_WORDS) {
  tokens <- str_split(norm_name(x), " ")[[1]]
  unique(tokens[nchar(tokens) >= 4 & !tokens %in% stop_words & !str_detect(tokens, "^\\d+$")])
}

## Place names that tie a letter to a state. Maharashtra is left out: the applicant's own address,
## printed on every reply, is there.
STATE_HINTS <- c(
  TN = paste0(
    "tamil ?nadu|chennai|madurai|coimbatore|salem|tiruchirappalli|tirunelveli|vellore|",
    "dharmapuri"
  ),
  KA = "karnataka|bengaluru|bangalore|mysuru|mysore|belagavi|hubballi|kalaburagi",
  TG = "telangana|hyderabad|warangal|karimnagar|nizamabad",
  DL = "\\bdelhi\\b"
)

## Last-resort match for a letter quoting neither a registration number nor a known PIO address:
## the office's distinctive words plus the filing date the letter cites. Low confidence.
office_and_date <- function(blob, info, stop_words = MATCH_STOP_WORDS, restrict = character()) {
  have <- name_tokens(blob, stop_words)
  m <- str_match_all(blob, DATE_RE)[[1]]
  dates <- if (nrow(m) > 0) {
    as.Date(
      sprintf("%s-%02d-%02d", m[, 4], as.integer(m[, 3]), as.integer(m[, 2])),
      format = "%Y-%m-%d"
    )
  } else {
    as.Date(character())
  }
  hinted <- names(STATE_HINTS)[vapply(
    STATE_HINTS, function(p) str_detect(blob, regex(p, ignore_case = TRUE)), logical(1)
  )]
  scored <- list()
  for (aid in names(info)) {
    if (length(restrict) > 0 && !aid %in% restrict) next
    want <- name_tokens(info[[aid]]$office, stop_words)
    if (length(want) == 0) next
    overlap <- sum(want %in% have) / length(want)
    if (overlap < 0.5) next
    date_hit <- any(as.character(dates) %in% as.character(info[[aid]]$dates))
    score <- overlap + (if (date_hit) 0.5 else 0) + (if (str_sub(aid, 1, 2) %in% hinted) 0.3 else 0)
    scored[[aid]] <- list(score = score, overlap = overlap, date_hit = date_hit, aid = aid)
  }
  if (length(scored) == 0) {
    return("")
  }
  ## Highest score first, ties broken by the larger id, as a descending tuple sort would
  ids <- names(scored)
  ord <- order(
    -vapply(scored, `[[`, 0, "score"), -vapply(scored, `[[`, 0, "overlap"),
    -vapply(scored, `[[`, 0, "date_hit"), xtfrm(ids) * -1
  )
  scored <- scored[ord]
  best <- scored[[1]]
  clear <- length(scored) == 1 || scored[[2]]$score < best$score - 0.25
  ok <- clear && ((best$date_hit && best$overlap >= 0.5) || best$overlap >= 0.99)
  if (ok) best$aid else ""
}
