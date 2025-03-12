import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void TermsOfServicePopUp(BuildContext context) {
  final loc = AppLocalizations.of(context)!;
  
  showDialog(
      context: context,
      builder: (context) => AlertDialog(
            content: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      loc.termsOfService,
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.acceptanceOfTerms),
                    _buildSectionText(loc.acceptanceOfTermsText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.eligibility),
                    _buildSectionText(loc.eligibilityText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.accountRegistration),
                    _buildSectionText(loc.accountRegistrationText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.licenseToUse),
                    _buildSectionText(loc.licenseToUseText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.userContent),
                    _buildSectionText(loc.userContentText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.prohibitedConduct),
                    _buildSectionText(loc.prohibitedConductText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.privacy),
                    _buildSectionText(loc.privacyText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.thirdPartyLinks),
                    _buildSectionText(loc.thirdPartyLinksText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.termination),
                    _buildSectionText(loc.terminationText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.disclaimers),
                    _buildSectionText(loc.disclaimersText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.limitationOfLiability),
                    _buildSectionText(loc.limitationOfLiabilityText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.indemnification),
                    _buildSectionText(loc.indemnificationText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.governingLaw),
                    _buildSectionText(loc.governingLawText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.severability),
                    _buildSectionText(loc.severabilityText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.entireAgreement),
                    _buildSectionText(loc.entireAgreementText),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        loc.termsAcknowledgement,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        loc.termsQuestionsContact,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(loc.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ));
}

Widget _buildSectionTitle(String title) {
  return Text(
    title,
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: Colors.black87,
    ),
  );
}

Widget _buildSectionText(String text) {
  return Text(
    text,
    style: TextStyle(fontSize: 16, color: Colors.black54),
    textAlign: TextAlign.justify,
  );
}
