/// Not on the web (tests on the VM): there is no browser to save into.
void saveFile(List<int> bytes, String fileName, String mimeType) {
  throw UnsupportedError('Saving files needs a browser');
}
