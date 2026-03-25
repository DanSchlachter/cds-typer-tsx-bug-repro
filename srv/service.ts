import cds from '@sap/cds';
import { Files } from '#cds-models/ReproService';

export default cds.service.impl(function () {
  this.on('READ', Files, async (req) => req.reply([]));
});
