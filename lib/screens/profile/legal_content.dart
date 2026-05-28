class LegalContactRow {
  const LegalContactRow({required this.label, required this.value});

  final String label;
  final String value;
}

class LegalWarning {
  const LegalWarning({required this.title, required this.body});

  final String title;
  final String body;
}

class LegalSection {
  const LegalSection({
    required this.number,
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
    this.contactRows = const [],
    this.warning,
    this.accent = false,
  });

  final String number;
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
  final List<LegalContactRow> contactRows;
  final LegalWarning? warning;
  final bool accent;
}

class LegalDocument {
  const LegalDocument({
    required this.heroTitle,
    required this.effectiveDate,
    required this.intro,
    required this.sections,
    required this.finalQuote,
    required this.finalBody,
  });

  final String heroTitle;
  final String effectiveDate;
  final String intro;
  final List<LegalSection> sections;
  final String finalQuote;
  final String finalBody;
}

const legalContactRows = [
  LegalContactRow(label: 'Company', value: 'FOMOwl Inc.'),
  LegalContactRow(label: 'Location', value: 'Lagos, Nigeria'),
  LegalContactRow(label: 'Email', value: 'info@fomowlhq.com'),
];

const termsDocument = LegalDocument(
  heroTitle: 'Terms of Service for Owllet',
  effectiveDate: '29/03/2026',
  intro:
      'Please read these terms carefully. By accessing Owllet, you enter a binding digital compact governing your use of our decentralized wallet infrastructure.',
  finalQuote: '"Not your keys, not your coins"',
  finalBody:
      'Owllet is designed to give you full control and ownership of your assets. With that control comes full personal responsibility. Use responsibly and stay safe.',
  sections: [
    LegalSection(
      number: '01',
      title: 'Agreement to Terms',
      accent: true,
      paragraphs: [
        'These Terms of Service govern your access to and use of Owllet, a non-custodial cryptocurrency wallet application provided by FOMOwl Inc. ("FOMOwl," "we," "us," or "our").',
        'By downloading, installing, or using Owllet, you agree to be bound by these Terms. If you do not agree, you must not use the app.',
      ],
    ),
    LegalSection(
      number: '02',
      title: 'Nature of the Service',
      paragraphs: [
        'Owllet is a non-custodial cryptocurrency wallet software. This means:',
      ],
      bullets: [
        'We do not hold, control, or have access to your private keys, seed phrases, or cryptocurrency assets.',
        'We do not execute, process, or intermediate any transactions on your behalf.',
        'We are not a bank, financial institution, custodian, or money transmitter.',
        'All transactions occur directly on the relevant blockchain networks through your device.',
      ],
    ),
    LegalSection(
      number: '03',
      title: 'Eligibility',
      paragraphs: [
        'You may use Owllet only if you are of legal age in your jurisdiction and are legally permitted to use cryptocurrency services under applicable law.',
        'You represent that your use complies with all local, state, national, and international laws and regulations.',
      ],
    ),
    LegalSection(
      number: '04',
      title: 'User Responsibilities',
      accent: true,
      paragraphs: ['You are solely responsible for:'],
      bullets: [
        'Safely storing and backing up your private keys and recovery seed phrase.',
        'Verifying transaction details including addresses, networks, tokens, and fees before signing.',
        'All activity conducted through your wallet.',
        'Maintaining the security of your device and accounts.',
      ],
      warning: LegalWarning(
        title: 'Important Warning',
        body:
            'If you lose your recovery seed phrase or private keys, your funds may be permanently inaccessible. FOMOwl Inc. cannot recover them.',
      ),
    ),
    LegalSection(
      number: '05',
      title: 'No Financial or Investment Advice',
      paragraphs: [
        'Owllet does not provide investment advice, trading recommendations, financial analysis, or any other professional guidance. All decisions are made at your own discretion and risk.',
      ],
    ),
    LegalSection(
      number: '06',
      title: 'Risk Disclosure',
      paragraphs: [
        'Cryptocurrency and blockchain technology involve significant risks, including but not limited to:',
      ],
      bullets: [
        'Extreme price volatility and potential total loss of funds.',
        'Smart contract failures, bugs, or exploits.',
        'Network congestion, forks, or protocol changes.',
        'Phishing, malware, and security vulnerabilities on your device.',
        'Regulatory or legal changes.',
      ],
    ),
    LegalSection(
      number: '07',
      title: 'Third-Party Integrations and Services',
      paragraphs: [
        'Owllet may provide access to or integrate with third-party services such as fiat on-ramps, off-ramps, decentralized exchanges, or blockchain explorers.',
        'These services are operated by independent parties. Any interactions, including KYC/AML processes, occur directly between you and the third party.',
        'You should review the third party\'s terms and privacy policy before use.',
      ],
    ),
    LegalSection(
      number: '08',
      title: 'Prohibited Activities',
      paragraphs: [
        'You agree not to use Owllet for any illegal, fraudulent, or harmful purpose, including:',
      ],
      bullets: [
        'Money laundering, terrorist financing, or sanctions evasion.',
        'Fraud, scams, or deceptive practices.',
        'Any activity that violates applicable laws or regulations in your jurisdiction.',
      ],
    ),
    LegalSection(
      number: '09',
      title: 'No Custody or Recovery',
      paragraphs: [
        'Owllet is strictly a software interface. FOMOwl Inc. has no access to your funds and cannot reverse, cancel, or modify any blockchain transaction.',
        'We cannot recover lost funds, seed phrases, or assets, and we cannot provide customer support for blockchain-level issues.',
      ],
    ),
    LegalSection(
      number: '10',
      title: 'Limitation of Liability',
      accent: true,
      paragraphs: [
        'To the maximum extent permitted by law, FOMOwl Inc. and its affiliates, officers, directors, employees, and agents shall not be liable for indirect, incidental, special, consequential, or punitive damages arising from your use of Owllet, including loss of funds, transaction errors, unauthorized access, or downtime.',
      ],
    ),
    LegalSection(
      number: '11',
      title: 'Indemnification',
      paragraphs: [
        'You agree to indemnify, defend, and hold harmless FOMOwl Inc. and its personnel from claims, losses, liabilities, damages, and expenses arising from your use of Owllet, your violation of these Terms or applicable laws, or any content or transactions you initiate.',
      ],
    ),
    LegalSection(
      number: '12',
      title: 'Service Availability and Modifications',
      paragraphs: [
        'We strive to provide reliable service but do not guarantee uninterrupted, error-free, or secure access. Owllet may be updated, modified, or temporarily unavailable for maintenance. We may discontinue features or the service itself at any time with or without notice.',
      ],
    ),
    LegalSection(
      number: '13',
      title: 'Intellectual Property',
      paragraphs: [
        'All rights, title, and interest in Owllet, including software, logos, trademarks, and content, belong to FOMOwl Inc. We grant you a limited, non-exclusive, non-transferable, revocable license to use Owllet for personal, non-commercial purposes in accordance with these Terms.',
      ],
    ),
    LegalSection(
      number: '14',
      title: 'Regulatory Compliance and Taxes',
      paragraphs: [
        'You are solely responsible for complying with all applicable laws, including tax reporting obligations, in your jurisdiction. Cryptocurrency transactions may have tax implications.',
      ],
    ),
    LegalSection(
      number: '15',
      title: 'Governing Law and Dispute Resolution',
      paragraphs: [
        'These Terms are governed by the laws applicable to FOMOwl Inc. in its operating jurisdiction, without regard to conflict-of-law principles.',
        'Disputes should first be resolved through good-faith negotiation. If unresolved, they may be submitted to the competent court or arbitration forum available under applicable law.',
      ],
    ),
    LegalSection(
      number: '16',
      title: 'Changes to Terms',
      paragraphs: [
        'We may update these Terms periodically. We will notify you of material changes through in-app notice or other reasonable means. Your continued use of Owllet after the effective date constitutes acceptance of the revised Terms.',
      ],
    ),
    LegalSection(
      number: '17',
      title: 'Contact Information',
      accent: true,
      contactRows: legalContactRows,
    ),
  ],
);

const privacyDocument = LegalDocument(
  heroTitle: 'Privacy Policy for Owllet',
  effectiveDate: '29/03/2026',
  intro:
      'This Privacy Policy explains how FOMOwl Inc. handles information when you use Owllet, our non-custodial cryptocurrency wallet.',
  finalQuote: 'You own your keys. You own your data.',
  finalBody:
      'Owllet is designed with maximum user privacy and control in mind. We collect as little as possible and keep sensitive wallet operations on your device.',
  sections: [
    LegalSection(
      number: '01',
      title: 'Introduction',
      accent: true,
      paragraphs: [
        'This Privacy Policy explains how FOMOwl Inc. ("we," "us," or "our") handles information when you use Owllet.',
        'We are committed to minimizing data collection and respecting user privacy. Owllet is built on the principle that you own your keys and your data.',
      ],
    ),
    LegalSection(
      number: '02',
      title: 'Non-Custodial Wallet',
      accent: true,
      paragraphs: [
        'Owllet does not store your private keys, seed phrases, or cryptocurrency assets. All sensitive operations happen locally on your device. We cannot access or control your funds.',
      ],
    ),
    LegalSection(
      number: '03',
      title: 'Information We Do Not Collect',
      paragraphs: [
        'For core wallet functionality, we do not collect or store:',
      ],
      bullets: [
        'Your name, email, phone number, address, or government-issued ID.',
        'Private keys or recovery seed phrases.',
        'Transaction signing data beyond what is publicly visible on-chain.',
      ],
    ),
    LegalSection(
      number: '04',
      title: 'Limited Technical Data',
      paragraphs: [
        'We may automatically collect minimal, non-personally identifiable technical information such as device type, operating system version, app version, anonymous crash reports, and aggregated usage statistics. This data is used solely for service improvement.',
      ],
    ),
    LegalSection(
      number: '05',
      title: 'Third-Party Services',
      paragraphs: [
        'When you use integrated third-party services such as exchanges, on-ramps, or off-ramps, you may provide personal information directly to those providers for compliance checks. FOMOwl Inc. does not collect, store, or process that third-party KYC data.',
        'Those interactions are governed by the third party\'s own terms and privacy policy.',
      ],
    ),
    LegalSection(
      number: '06',
      title: 'Sharing and Disclosure',
      paragraphs: [
        'We do not sell, rent, or trade user data. We may disclose limited technical data only if required by law, valid legal process, or necessary to protect our legal rights or safety.',
      ],
    ),
    LegalSection(
      number: '07',
      title: 'Data Security',
      paragraphs: [
        'We implement reasonable technical measures to protect any data we handle. However, no system is completely secure. You are responsible for securing your device, passcode, recovery phrase, and wallet credentials.',
      ],
    ),
    LegalSection(
      number: '08',
      title: 'Blockchain Data',
      paragraphs: [
        'Blockchain transactions are public and immutable. Wallet addresses and transaction history may be visible to anyone and could potentially be linked to your identity through external analysis. Owllet has no control over public blockchain data.',
      ],
    ),
    LegalSection(
      number: '09',
      title: 'International Transfers',
      paragraphs: [
        'Any limited data we process may be handled in Nigeria, the United States, or other jurisdictions. Data protection laws vary by country.',
      ],
    ),
    LegalSection(
      number: '10',
      title: 'Your Rights',
      paragraphs: [
        'Depending on your location, laws such as GDPR may grant rights regarding your data. Since Owllet collects very little personal data for core wallet use, the practical scope of these rights is limited. For third-party KYC data, contact the relevant provider.',
      ],
    ),
    LegalSection(
      number: '11',
      title: 'Children\'s Privacy',
      paragraphs: [
        'Owllet is not directed at children under 13. We do not knowingly collect data from children.',
      ],
    ),
    LegalSection(
      number: '12',
      title: 'Cookies and Tracking',
      paragraphs: [
        'Owllet may use limited local storage or analytics for performance and crash reporting. We do not engage in cross-app tracking for advertising purposes.',
      ],
    ),
    LegalSection(
      number: '13',
      title: 'Changes to This Policy',
      paragraphs: [
        'We may update this Privacy Policy. Material changes will be notified through the app or other reasonable means. Continued use after changes constitutes acceptance.',
      ],
    ),
    LegalSection(
      number: '14',
      title: 'Contact Information',
      accent: true,
      contactRows: legalContactRows,
    ),
  ],
);
