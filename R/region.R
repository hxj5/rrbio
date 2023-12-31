# region.R - genomic region routine


#' Merge Adjacent Regions of Single Group
#' @keywords internal
#' @noRd
reg_merge_adjacent_regions1 <- function(df, chrom, start, end, value, 
                                        max_gap = 0, na.rm = TRUE)
{
  if (! chrom %in% colnames(df))
    stop(sprintf("'%s' is not a column of df.", chrom))
  if (! start %in% colnames(df))
    stop(sprintf("'%s' is not a column of df.", start))
  if (! end %in% colnames(df))
    stop(sprintf("'%s' is not a column of df.", end))
  if (! value %in% colnames(df))
    stop(sprintf("'%s' is not a column of df.", value))
    
  df <- df[, c(chrom, start, end, value)]
  colnames(df) <- c("chrom", "start", "end", "value")
    
  if (na.rm)   
    df <- stats::na.omit(df)

  if (nrow(df) <= 0) {
    warning("processed-1 df is empty!")
    return(df)
  }
    
  n_invalid <- sum(df$start > df$end)
  if (n_invalid > 0)
    stop(sprintf("%d invalid regions with start > end!", n_invalid))
    
  df <- df %>%
    dplyr::distinct(chrom, start, end, .keep_all = TRUE) %>%
    dplyr::arrange(chrom, start, end)
    
  if (nrow(df) <= 0) {
    warning("processed-2 df is empty!")
    return(df)
  }

  # check invalid overlapping regions
  n_invalid <- 0
  for (i in 2:nrow(df)) {
    if (identical(df$chrom[i - 1], df$chrom[i]) && df$start[i] <= df$end[i - 1])
      n_invalid <- n_invalid + 1
  }
  if (n_invalid > 0)
    stop(sprintf("%d invalid regions with start_next <= end_pre!", n_invalid))
    
  df_new <- df    # allocate enough space for new dataframe
  i <- 1
  ch_new <- df_new$chrom[1] <- df$chrom[1]
  s_new <- df_new$start[1] <- df$start[1]
  e_new <- df_new$end[1] <- df$end[1]
  v_new <- df_new$value[1] <- df$value[1]
    
  for (j in 2:nrow(df)) {
    ch <- df$chrom[j]
    s <- df$start[j]
    e <- df$end[j]
    v <- df$value[j]
    
    if (identical(ch, ch_new) && s - e_new - 1 <= max_gap && 
        identical(v, v_new)) {            # adjacent region & same value
      e_new <- df_new$end[i] <- e
    } else {                              # a new region
      i <- i + 1
      ch_new <- df_new$chrom[i] <- ch
      s_new <- df_new$start[i] <- s
      e_new <- df_new$end[i] <- e
      v_new <- df_new$value[i] <- v
    }
  }
    
  df_new <- df_new[1:i, ]
  return(df_new)
}


#' Merge Adjacent Regions
#'
#' This function is aimed to merge adjacent regions with the same `value`s in 
#' each `group` (if available). The input regions in each group should be
#' non-overlapping regions (i.e., the `end` position of previous region should
#' be smaller than the `start` position of current region).
#'
#' @param df A dataframe.
#' @param chrom A string. Name of the column storing chromosome names of the
#'   regions.
#' @param start A string. Name of the column storing start positions 
#'   (1-based, inclusive) of the regions.
#' @param end A string. Name of the column storing end positions 
#'   (1-based, inclusive) of the regions.
#' @param value A string. Name of the column storing the values of the regions.
#' @param group A string. Name of the column storing the group names. Setting
#'   to `NULL` to indicate single group.
#' @param max_gap An integer. The maximum gap length that is allowed between
#'   two adjacent regions. `0` for strict adjacence.
#' @param na.rm A bool. Whether the regions containing `NA` should be removed.
#' @param keep_name A bool. Whether to keep input column names in the returned
#'   dataframe.
#' @return A dataframe containing columns "`chrom`", "`start`", "`end`", 
#'   "`value`", and "`group`" (if available). If `keep_name` is `TRUE`, then
#'   the column names would keep the same with the input dataframe.
#'
#' @export
#' @examples
#' # single group
#' df <- data.frame(
#'   chrom = c("chr1", "chr1", "chr1", "chr2", "chr2"),
#'   begin = c(1, 101, 201, 101, 201),
#'   end = c(100, 200, 300, 200, 300),
#'   value = c(1, 1, 2, 2, 3)
#' )
#' reg_merge_adjacent_regions(df, "chrom", "begin", "end", "value")
#'
#' # more than one groups
#' tmp1 <- tmp2 <- df
#' tmp1$group <- "g1"
#' tmp2$group <- "g2"
#' df2 <- rbind(tmp1, tmp2)
#' reg_merge_adjacent_regions(df2, "chrom", "begin", "end", "value", "group")
reg_merge_adjacent_regions <- function(df, chrom, start, end, value, 
                                       group = NULL, max_gap = 0, 
                                       na.rm = TRUE, keep_name = TRUE)
{
  rename_df <- function(df) {
    if (is.null(group))
      colnames(df) <- c(chrom, start, end, value)
    else
      colnames(df) <- c(chrom, start, end, value, group)
    return(df)
  }

  if (! chrom %in% colnames(df))
    stop(sprintf("'%s' is not a column of df.", chrom))
  if (! start %in% colnames(df))
    stop(sprintf("'%s' is not a column of df.", start))
  if (! end %in% colnames(df))
    stop(sprintf("'%s' is not a column of df.", end))
  if (! value %in% colnames(df))
    stop(sprintf("'%s' is not a column of df.", value))
    
  if (! is.null(group))
    if (! group %in% colnames(df))
      stop(sprintf("'%s' is not a column of df.", group))
      
  if (is.null(group)) {
    df <- df[, c(chrom, start, end, value)]
    colnames(df) <- c("chrom", "start", "end", "value")      
  } else {
    df <- df[, c(chrom, start, end, value, group)]
    colnames(df) <- c("chrom", "start", "end", "value", "group")     
  }

  if (na.rm)
    df <- stats::na.omit(df)
      
  if (nrow(df) <= 0) {
    warning("processed df is empty!")
    if (keep_name)
      df <- rename_df(df)
    return(df)
  }
    
  if (is.null(group)) {
    df_new <- reg_merge_adjacent_regions1(
      df = df,
      chrom = "chrom", start = "start", end = "end", value = "value",
      max_gap = max_gap,
      na.rm = na.rm
    )
    if (keep_name)
      df_new <- rename_df(df_new)
    return(df_new)
  } else {
    df_new <- NULL
    for (g in base::unique(df$group)) {
      df_group <- df[df$group == g, ]
      df_new1 <- reg_merge_adjacent_regions1(
        df = df_group,
        chrom = "chrom", start = "start", end = "end", value = "value",
        max_gap = max_gap,
        na.rm = na.rm
      )
      df_new1$group <- g
      df_new <- base::rbind(df_new, df_new1)
    }
    df_new <- as.data.frame(df_new)
    if (keep_name)
      df_new <- rename_df(df_new)
    return(df_new)
  }
}

