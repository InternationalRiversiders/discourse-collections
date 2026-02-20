export default function () {
  this.route("collections", function () {
    this.route("mine", { path: "/mine/:scope" });
    this.route("show", { path: "/:id" });
  });
}
