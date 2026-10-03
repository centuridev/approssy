const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");

const applyChanges = process.argv.includes("--apply");

const categories = {
  unghie: [
    {id: "french", name: "French", price: 10, duration: 0, active: true},
    {
      id: "baby-boomer",
      name: "Baby-boomer",
      price: 5,
      duration: 0,
      active: true,
    },
    {
      id: "sfumature-bicolore",
      name: "Sfumature bicolore",
      price: 10,
      duration: 0,
      active: true,
    },
    {
      id: "effetto-specchio",
      name: "Effetto specchio",
      price: 10,
      duration: 0,
      active: true,
    },
    {
      id: "nail-art-unghia",
      name: "Nail Art un'unghia",
      price: 5,
      duration: 0,
      active: true,
    },
    {
      id: "nail-art-due-unghie",
      name: "Nail Art due unghie",
      price: 10,
      duration: 0,
      active: true,
    },
    {
      id: "nail-art-tutte-unghie",
      name: "Nail Art su tutte le unghie",
      price: 15,
      duration: 0,
      active: true,
    },
    {
      id: "swarovski",
      name: "Swarovski",
      price: 5,
      duration: 0,
      active: true,
    },
    {id: "design-3d", name: "Design 3D", price: 10, duration: 0, active: true},
    {
      id: "unghia-swarovski",
      name: "Unghia in Swarovski",
      price: 10,
      duration: 0,
      active: true,
    },
  ],
  lashes: [
    {
      id: "swarovski",
      name: "Swarovski",
      price: 5,
      duration: 0,
      active: true,
    },
    {
      id: "tocco-colore",
      name: "Tocco di colore",
      price: 5,
      duration: 0,
      active: true,
    },
    {id: "raggi", name: "Raggi", price: 10, duration: 0, active: true},
  ],
  pedicure: [
    {
      id: "ricostruzione-unghia",
      name: "Ricostruzione un'unghia",
      price: 5,
      duration: 0,
      active: true,
    },
    {
      id: "ricostruzione-due-unghie",
      name: "Ricostruzione due unghie",
      price: 10,
      duration: 0,
      active: true,
    },
    {
      id: "swarovski",
      name: "Swarovski",
      price: 5,
      duration: 0,
      active: true,
    },
    {
      id: "unghia-swarovski",
      name: "Unghia Swarovski",
      price: 10,
      duration: 0,
      active: true,
    },
    {
      id: "nail-art-unghia",
      name: "Nail Art su un'unghia",
      price: 5,
      duration: 0,
      active: true,
    },
    {
      id: "effetto-specchio",
      name: "Effetto specchio",
      price: 10,
      duration: 0,
      active: true,
    },
    {id: "french", name: "French", price: 10, duration: 0, active: true},
    {
      id: "baby-boomer",
      name: "Baby-boomer",
      price: 5,
      duration: 0,
      active: true,
    },
    {
      id: "sfumatura-bicolore",
      name: "Sfumatura bicolore",
      price: 10,
      duration: 0,
      active: true,
    },
  ],
};

async function main() {
  if (!applyChanges) {
    console.log("DRY RUN: no Firestore writes were performed.");
    console.log("Run `node scripts/seedServiceExtras.cjs --apply` to write.");
    console.log(JSON.stringify(categories, null, 2));
    return;
  }

  admin.initializeApp();
  const db = admin.firestore();

  for (const [category, extras] of Object.entries(categories)) {
    await db.collection("service_extras").doc(category).set(
      {
        category,
        extras,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    console.log(`Updated service_extras/${category}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
