#' Detect collocations from text
#' 
#' Detects collocations (currently, bigrams) from texts or a corpus, returning a
#' data.frame of collocations and their scores, sorted by the likelihood ratio
#' \eqn{G^2} and Pearson's \eqn{\chi^2}.
#' @param x a text, a character vector of texts, or a corpus
#' @param method association measure for detecting collocations.  Available
#'   measures for bigrams are:
#'   \describe{ 
#'   \item{\code{"lr"}}{The likelihood ratio statistic \eqn{G^2}, computed as:
#'          \deqn{2 * \sum_i \sum_j (n_{ij} * log \frac{n_{ij}}{m_{ij}}}
#'      }
#'   \item{\code{"chi2"}}{Pearson's \eqn{\chi^2} statistic, computed as:
#'          \deqn{\sum_i \sum_j \frac{(n_{ij} - m_{ij})^2}{m_{ij}}}
#'      }
#'   \item{\code{"pmi"}}{point-wise mutual information score, computed as log \eqn{n_{11}/m{11}}}
#'   \item{\code{"dice"}}{the Dice coefficient, computed as \eqn{n_{11}/n_{1.} + n_{.1}}}
#'   \item{\code{"all"}}{returns all of the above}
#'   }
#' @param n length of the collocation.  Only bigrams (\code{n=2}) implemented so
#'   far.
#' @param top the number of collocations to return, sorted in descending order
#'   of the requested statistic, or \eqn{G^2} if none is specified.
#' @param ... additional parameters
#' @return A data.frame of collocations, their frequencies, and the computed 
#'   association measure.
#' @export
#' @import data.table
#' @references Add some.
#' @seealso bigrams, trigrams 
#' @author Kenneth Benoit
#' @examples
#' collocations(inaugTexts, top=10)
#' collocations(inaugCorpus, top=10, method="chi2")
collocations <- function(x, ...) {
    UseMethod("collocations")
}
    
#' @rdname collocations
#' @export    
collocations.character <- function(x, method=c("lr", "chi2", "pmi", "dice", "all"), n=2, top=NULL, ...) {
    method <- match.arg(method)
    if (n != 2) stop("Only bigrams (n=2) implemented so far.")
    
    # to prevent warning messages during CHECK
    #w1 <- w2 <- count <- w1w2n <- w1w2Exp <- w1notw2Exp <- notw1w2 <- notw1w2Exp <- NULL
    #notw1notw2 <- notw1notw2Exp <- NULL
    
    text <- clean(x, ...)
    t <- unlist(tokenize(text), use.names=FALSE)
    
    # create a data.table of all adjacent bigrams
    wordpairs <- data.table(w1 = t[1:(length(t)-1)], 
                            w2 = t[2:length(t)], 
                            count = 1)
    
    # set the data.table sort key
    setkey(wordpairs, w1, w2)
    
    # tabulate (count) w1 w2 pairs
    wordpairsTable <- wordpairs[, j=sum(count), by="w1,w2"]
    setnames(wordpairsTable, "V1", "w1w2n")
    
    # tabulate all word marginal counts
    w1Table <- wordpairs[, sum(count), by=w1]
    setnames(w1Table, "V1", "w1n")
    setkey(w1Table, w1)
    
    setkey(wordpairsTable, w1)
    suppressWarnings(allTable <- wordpairsTable[w1Table])
    # otherwise gives an encoding warning
    
    # tabulate all w2 counts
    w2Table <- wordpairs[, sum(count), by=w2]
    setnames(w2Table, "V1", "w2n")
    setkey(w2Table, w2)
    
    setkey(allTable, w2)
    suppressWarnings(allTable2 <- allTable[w2Table])
    # otherwise gives an encoding warning
    
    setkey(allTable2, w1, w2)
    
    N <- sum(allTable2$w1w2n)  # total number of collocations (table N for all tables)
    
    # fill in cells of 2x2 tables
    allTable2$w1notw2 <- allTable2$w1n - allTable2$w1w2
    allTable2$notw1w2 <- allTable2$w2n - allTable2$w1w2
    allTable2$notw1notw2 <- N - (allTable2$w1w2 + allTable2$w1notw2 + allTable2$notw1w2)
    
    # calculate expected values
    allTable2$w1w2Exp <- allTable2$w1n * allTable2$w2n / N
    allTable2$w1notw2Exp <- allTable2$w1n * (N - allTable2$w2n) / N
    allTable2$notw1w2Exp <- allTable2$w2n * (N - allTable2$w1n) / N
    allTable2$notw1notw2Exp <- (N - allTable2$w2n) * (N - allTable2$w1n) / N
    
    # vectorized lr stat
    epsilon <- .000000001  # to offset zero cell counts
    if (method=="all" | method=="lr") {
        allTable2$lrratio <- 2 *  ((allTable2$w1w2n * log(allTable2$w1w2n / allTable2$w1w2Exp + epsilon)) +
                                       (allTable2$w1notw2 * log(allTable2$w1notw2 / allTable2$w1notw2Exp + epsilon)) +
                                       (allTable2$notw1w2 * log(allTable2$notw1w2 / allTable2$notw1w2Exp + epsilon)) +
                                       (allTable2$notw1notw2 * log(allTable2$notw1notw2 / allTable2$notw1notw2Exp + epsilon)))
    }
    if (method=="all" | method=="chi2") {
        allTable2$chi2 <- (allTable2$w1w2n - allTable2$w1w2Exp)^2 / allTable2$w1w2Exp +
            (allTable2$w1notw2 - allTable2$w1notw2Exp)^2 / allTable2$w1notw2Exp +
            (allTable2$notw1w2 - allTable2$notw1w2Exp)^2 / allTable2$notw1w2Exp +
            (allTable2$notw1notw2 - allTable2$notw1notw2Exp)^2 / allTable2$notw1notw2Exp
    }
    if (method=="all" | method=="pmi") {
        allTable2$pmi <- log(allTable2$w1w2n / allTable2$w1w2Exp)
    }
    if (method=="all" | method=="dice") {
        allTable2$dice <- 2 * allTable2$w1w2n / (allTable2$w1w2n + allTable2$w1notw2) 
    }
    if (method=="chi2") {
        allTable2 <- allTable2[order(-chi2)]
        df <- data.frame(collocation=paste(allTable2$w1, allTable2$w2),
                         count=allTable2$w1w2n,
                         X2=allTable2$chi2)
    } else if (method=="pmi") {
        allTable2 <- allTable2[order(-pmi)]
        df <- data.frame(collocation=paste(allTable2$w1, allTable2$w2),
                         count=allTable2$w1w2n,
                         pmi=allTable2$pmi) 
    
    } else if (method=="dice") {
        allTable2 <- allTable2[order(-dice)]
        df <- data.frame(collocation=paste(allTable2$w1, allTable2$w2),
                         count=allTable2$w1w2n,
                         dice=allTable2$dice) 
    } else {
        allTable2 <- allTable2[order(-lrratio)]
        df <- data.frame(collocation=paste(allTable2$w1, allTable2$w2),
                         count=allTable2$w1w2n,
                         G2=allTable2$lrratio) 
    }
        
    if (method=="all") {
        df$G2 <- allTable2$lrratio
        df$X2 <- allTable2$chi2
        df$pmi <- allTable2$pmi
        df$dice <- allTable2$dice
    }
        
    df[1:ifelse(is.null(top), N, top), ]
}

#' @rdname collocations
#' @export
collocations.corpus <- function(x, method=c("lr", "chi2", "pmi", "dice", "all"), n=2, top=NULL, ...) {
    collocations(texts(x), method, n, top, ...)
}


#' convert phrases into single tokens
#' 
#' Replace multi-word phrases in text(s) with a compound version of the phrases 
#' concatenated with  \code{connector} (by default, the "\code{_}" character) to
#' form a single token.  This prevents tokenization of the phrases during 
#' subsequent processing by eliminating the whitespace delimiter.
#' @param txts character or character vector of texts
#' @param dictionary a list or named list (such as a quanteda dictionary) that 
#'   contains some phrases, defined as multiple words delimited by whitespace. 
#'   These can be up to 9 words long.
#' @param connector the concatenation character that will connect the words 
#'   making up the multi-word phrases.  The default \code{_} is highly 
#'   recommended since it will not be removed during normal cleaning and 
#'   tokenization (while nearly all other punctuation characters, at least those
#'   in the POSIX class \code{[[:punct:]]}) will be removed.
#' @return character or character vector of texts with phrases replaced by 
#'   compound "words" joined by the connector
#' @export
#' @examples
#' mytexts <- c("The new law included a capital gains tax, and an inheritance tax.",
#'              "New York City has raised a taxes: an income tax and a sales tax.")
#' mydict <- list(tax=c("tax", "income tax", "capital gains tax", "inheritance tax"))
#' (cw <- compoundWords(mytexts, mydict))
#' print(dfm(cw), show.values=TRUE)
#' 
#' # when used as a dictionary for dfm creation
#' mydfm2 <- dfm(cw, dictionary=lapply(mydict, function(x) gsub(" ", "_", x)))
#' print(mydfm2, show.values=TRUE)
#' # to pick up "taxes" in the second text, set regular_expression=TRUE
#' mydfm3 <- dfm(cw, dictionary=lapply(mydict, function(x) gsub(" ", "_", x)),
#'               dictionary_regex=TRUE)
#' print(mydfm3, show.values=TRUE)
compoundWords <- function(txts, dictionary, connector="_") {
    # get the tokenized list of compound phrases from a dictionary (list)
    phrases <- unlist(dictionary, use.names=FALSE)
    compoundPhrases <- phrases[grep(" ", phrases)]
    compoundPhrasesList <- tokenize(compoundPhrases)
    
    # contenate the phrases in
    # gsub("(word1)\\s(word2)", "\\1_\\2", "word1 word2")
    ## [1] "word1_word2"
    for (l in compoundPhrasesList) {
        re.pattern <- paste("(", 
                            paste(l, collapse=")\\s("),
                            ")", sep="")
        re.replace <- paste("\\", 1:length(l), sep="", collapse=connector)
        txts <- gsub(re.pattern, re.replace, txts, perl=TRUE)
    }
    txts    
}




