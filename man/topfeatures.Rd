% Generated by roxygen2 (4.0.2): do not edit by hand
\name{topfeatures}
\alias{topFeatures}
\alias{topfeatures}
\alias{topfeatures.dfm}
\title{list the most frequent features}
\usage{
topfeatures(x, n = 10, decreasing = TRUE, ci = 0.95)

\method{topfeatures}{dfm}(x, n = 10, decreasing = TRUE, ci = 0.95)
}
\arguments{
\item{x}{the object whose features will be returned}

\item{n}{how many top features should be returned}

\item{decreasing}{If TRUE, return the \code{n} most frequent features, if
FALSE, return the \code{n} least frequent features}

\item{ci}{confidence interval from 0-1.0 for use if dfm is resampled}
}
\value{
A named numeric vector of feature counts, where the names are the feature labels.
}
\description{
List the most frequently occuring features in a \link{dfm}
}
\examples{
topfeatures(dfm(inaugCorpus))
topfeatures(dfm(inaugCorpus, stopwords=TRUE))
# least frequent features
topfeatures(dfm(inaugCorpus), decreasing=FALSE)
}

