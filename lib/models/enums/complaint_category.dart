enum ComplaintCategory {
  overcharged('Overcharged'),
  poorWork('Poor quality work'),
  behaviour('Rude behaviour'),
  noShow('Mechanic did not arrive'),
  other('Other');

  const ComplaintCategory(this.label);

  final String label;
}
