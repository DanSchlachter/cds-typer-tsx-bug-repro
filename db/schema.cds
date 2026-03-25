using { managed } from '@sap/cds/common';
using { sap.attachments.MediaData } from '@cap-js/attachments';

namespace repro;

entity Files : managed, MediaData {
  key ID   : String(64);
      path : String(1000);
}
