// This file was generated by Rcpp::compileAttributes
// Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#include <Rcpp.h>

using namespace Rcpp;

// matchOnPs
DataFrame matchOnPs(std::vector<double> propensityScores, std::vector<int> treatment, unsigned int maxRatio, double caliper);
RcppExport SEXP CohortMethod_matchOnPs(SEXP propensityScoresSEXP, SEXP treatmentSEXP, SEXP maxRatioSEXP, SEXP caliperSEXP) {
BEGIN_RCPP
    SEXP __sexp_result;
    {
        Rcpp::RNGScope __rngScope;
        Rcpp::traits::input_parameter< std::vector<double> >::type propensityScores(propensityScoresSEXP );
        Rcpp::traits::input_parameter< std::vector<int> >::type treatment(treatmentSEXP );
        Rcpp::traits::input_parameter< unsigned int >::type maxRatio(maxRatioSEXP );
        Rcpp::traits::input_parameter< double >::type caliper(caliperSEXP );
        DataFrame __result = matchOnPs(propensityScores, treatment, maxRatio, caliper);
        PROTECT(__sexp_result = Rcpp::wrap(__result));
    }
    UNPROTECT(1);
    return __sexp_result;
END_RCPP
}
