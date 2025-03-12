import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void PrivacyPolicyPopUp(BuildContext context) {
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
                      loc.privacyPolicy,
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.informationWeCollect),
                    _buildSectionText(loc.informationWeCollectText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.howWeUseInformation),
                    _buildSectionText(loc.howWeUseInformationText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.dataRetention),
                    _buildSectionText(loc.dataRetentionText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.dataSharing),
                    _buildSectionText(loc.dataSharingText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.security),
                    _buildSectionText(loc.securityText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.cookies),
                    _buildSectionText(loc.cookiesText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.thirdPartyServices),
                    _buildSectionText(loc.thirdPartyServicesText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.childrensPrivacy),
                    _buildSectionText(loc.childrensPrivacyText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.changesPrivacyPolicy),
                    _buildSectionText(loc.changesPrivacyPolicyText),
                    const SizedBox(height: 20),
                    _buildSectionTitle(loc.contactUs),
                    _buildSectionText(loc.contactUsText),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        loc.privacyPolicyConsent,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontStyle: FontStyle.italic),
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
