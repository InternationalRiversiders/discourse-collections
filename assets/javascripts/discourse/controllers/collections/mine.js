import Controller from "@ember/controller";

export default class CollectionsMineController extends Controller {
  get collections() {
    return this.model?.collections || [];
  }

  get title() {
    return this.model?.title || "";
  }
}
