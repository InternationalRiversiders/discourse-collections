export default function () {
  this.route("collections", function () {
    this.route("show", { path: "/:id" });
  });
}
