import Controller from "@ember/controller";

export default class UserCollectionsController extends Controller {
  get collections() {
    return this.model?.collections || [];
  }
}
