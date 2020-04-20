getLooks <- function(
    df, aoi_collection, scope, intra_scope_window = c(0, 0), intra_scope_cut = TRUE,
    count_na_fixations = FALSE, stop_if_multiple_hit_names_in_single_fixation = TRUE) {

  # check if rownames are equal to a sequence of corresponding rownumbers
  if (!isTRUE((all.equal(as.numeric(rownames(df)), 1:nrow(df))))) stop("The df is not in sequence. Do not remove rows!")


  # check if intra_scope_window was passed as an argument, if so ...
  # ... use time ranges defined by intra_scope_window to overwrite scope
  if (!missing(intra_scope_window)) {

    # Add the starttime (intra_scope_window[1]) to every start position (scope$start) ...
    # ... of the recording timestamp to get the actual start window in milliseconds
    starting_times <- df$RecordingTimestamp[scope$start] + intra_scope_window[1]
    # Add the endtime argument to the starting times
    ending_times <- starting_times + intra_scope_window[2]

    # find the closest matching index for starting and ending times
    # find closest match (http://adomingues.github.io/2015/09/24/finding-closest-element-to-a-number-in-a-list/)
    start_indexes <- unlist(
      lapply(
        starting_times,
        function(x) which.min(abs(df$RecordingTimestamp - x))
      )
    )
    end_indexes <- unlist(
      lapply(
        ending_times,
        function(x) which.min(abs(df$RecordingTimestamp - x))
      )
    )

    # overwrite scope
    scope <- list(start = start_indexes, end = end_indexes)
  }


  # destructure aoi_collection
  column_name <- aoi_collection$column_name
  # store all hit_names
  hit_names = c()
  for (aoi in aoi_collection$aoilist) {
    hit_names <- c(hit_names, aoi$hit_name)
  }

  # create a storage container (i.e. a empty lists) for all hit_names ...
  # ... that track looking times over all trials (e.g., looking_times$left)
  looking_times <- setNames(vector("list", length(hit_names)), hit_names)

  # flag if first looks should be used (if there is only one hitname FLs aren’t  necessary)
  use_first_looks <- ifelse(length(hit_names) == 1, FALSE, TRUE)

  # storage container for first_looks
  first_looks <- c()


  # loop over scope/trials
  for (seq in seq_along(scope$start)) {
    current_start <- scope$start[seq]
    current_end <- scope$end[seq]

    # get all FixationIndexes in current trial
    inter_trial_FixationIndexes <- df$FixationIndex[current_start:current_end]


    # Filter out all NAs within the current and check if there are still...
    # ... valid fixations left. If so skip current trial/scope
    if (length(na.omit(inter_trial_FixationIndexes)) == 0) {
      # Append 0 to current trials and NA to FirstLook in this trial
      for (hn in hit_names) {
        looking_times[[hn]] = c(looking_times[[hn]], 0)
      }
      if (use_first_looks) {
        first_looks <- c(first_looks, NA)
      }
      # go to next trial
      next
    }


    # init storage containers for all fixation indexes for hit_names in the current trial
    current_trial_total_duration <- setNames(vector("list", length(hit_names)), hit_names)
    for (hn in hit_names) {
      # set/reset to current trial duration to 0
      current_trial_total_duration[[hn]] = 0
    }
    # reset first look flag and state
    found_first_look <- FALSE
    first_look <- ""


    # get first and last FixationIndex (remove NAs)
    min_FixationIndex <- min(inter_trial_FixationIndexes, na.rm = TRUE)
    max_FixationIndex <- max(inter_trial_FixationIndexes, na.rm = TRUE)

    # operate WITHIN the current fixation pair (i.e., within current trial)
    for (i in min_FixationIndex:max_FixationIndex) {

      # get all hit names within current fixation index
      hit_names_in_FixationIndex <- df[[column_name]][which(df$FixationIndex == i)]

      # check if multiple hit names are in current fixation index
      if (stop_if_multiple_hit_names_in_single_fixation) { # maybe useful to add a length constrain as well:  && length(hit_names) > 1
        # compare current hit_names_in_FixationIndex against hit_names
        hit_names_logical <- hit_names %in% hit_names_in_FixationIndex
        # hit_names_logical should only contain TRUE once (https://stackoverflow.com/a/2191824/2258480)
        if (sum(hit_names_logical, na.rm = TRUE) > 1) { # best way to count TRUE values
          stop(paste("The current Fixation Index:", i, "contains multiple AOI hit names!", sep = " "))
        }
        # check for single hitname AOIs if the contain the hit_name AND FALSE
        if (length(hit_names) == 1 &&
            hit_names %in% hit_names_in_FixationIndex &&
            FALSE %in% hit_names_in_FixationIndex) {
          stop(paste("The current Fixation Index:", i, "contains", hit_names, "and FALSE!", sep = " "))
        }
      }


      # iterate over hit names
      for (hn in hit_names) {

        if (hn %in% hit_names_in_FixationIndex ) {

          # check if the first fixation index started before the current_start and if intra_scope_cut is TRUE
          if (i == min_FixationIndex && which(df$FixationIndex == i)[1] < current_start && intra_scope_cut) {
            # get start and end milliseconds
            start_ms <- df$RecordingTimestamp[current_start]
            end_ms <-  df$RecordingTimestamp[which(df$FixationIndex == i)][length(which(df$FixationIndex == i))]

            # set the difference of start_ms and end_ms to the current GazeEventDuration
            current_GazeEventDuration <- end_ms - start_ms
            # Add it to the total
            current_trial_total_duration[[hn]] <- current_trial_total_duration[[hn]] + current_GazeEventDuration

            # set first_look if flag is not set
            if (!found_first_look && use_first_looks) {
              first_look <- hn
              found_first_look <- TRUE
            }

            # go to the next fixation index
            break
          }

          # check if the last fixation index continues after the current_end_pos and if markercut is TRUE
          if (i == max_FixationIndex && which(df$FixationIndex == i)[length(which(df$FixationIndex == i))] > current_end && intra_scope_cut) {
            # get start and end milliseconds
            start_ms <- df$RecordingTimestamp[which(df$FixationIndex == i)][1]
            end_ms <-  df$RecordingTimestamp[current_end]

            # set the difference of start_ms and end_ms to the current GazeEventDuration
            current_GazeEventDuration <- end_ms - start_ms
            # Add it to the total
            current_trial_total_duration[[hn]] <- current_trial_total_duration[[hn]] + current_GazeEventDuration

            # set first_look if flag is not set
            if (!found_first_look && use_first_looks) {
              first_look <- hn
              found_first_look <- TRUE
            }

            # go to the next fixation index
            break
          }

          # If intra_scope_cut is FALSE continue here ...
          # Grab the current GazeEventDuration chunk and select the first value
          current_GazeEventDuration <- df$GazeEventDuration[which(df$FixationIndex == i)][1]

          # Add it to the total
          current_trial_total_duration[[hn]] <- current_trial_total_duration[[hn]] + current_GazeEventDuration

          # set first_look if flag is not set
          if (!found_first_look) {
            first_look <- hn
            found_first_look <- TRUE
          }
        }
      }
    }


    # Append it to the Trial Lists
    for (hn in hit_names) {
      looking_times[[hn]] <- c(looking_times[[hn]], current_trial_total_duration[[hn]])
    }
    # Append first look to list
    # check if first_look was there
    if (first_look == "" && use_first_looks) {
      first_look = NA
    }
    if (use_first_looks) {
      first_looks <- c(first_looks, first_look)
    }

  }

  # END Function
  # Returns

  # if there is only one hit_name it does not need to be in a nested list
  if (length(hit_names) == 1) {
    looking_times <- unlist(looking_times[[1]])
  }

  if (use_first_looks) {
    return(
      list(
        looking_times = looking_times,
        first_looks = first_looks
      )
    )
  }

  return(list(looking_times = looking_times))
}