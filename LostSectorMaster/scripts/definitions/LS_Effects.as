#include "include/resource_constants.as"
import orbitals;
import hooks;
import pickups;
import resources;
import influence;
import attributes;
import anomalies;
import camps;
import research;
import buildings;
from buildings import getBuildingID;
import artifacts;
import orders;
from traits import ITraitEffect;
from influence import InfluenceStore;
from pickups import IPickupHook;
from anomalies import IAnomalyHook;
from abilities import Ability, IAbilityHook;
from research import ITechnologyHook;
from map_effects import parseResourceSpec;
import constructions;
from constructions import IConstructionHook;
import random_events;
import cargo;
import generic_hooks;
import void gainRandomCard(Empire@ emp) from "card_effects";

#section server
from object_stats import ObjectStatType, getObjectStat;
from objects.Asteroid import createAsteroid;
from objects.Anomaly import createAnomaly;
from empire import Creeps;
from objects.Oddity import createSlipstream;
from objects.Artifact import createArtifact;
from piracy import spawnPirateShip;
from game_start import generateNewSystem, SystemGenerateHook;
import object_creation;
import systems;
import influence_global;
import void makeCreepCamp(const vec3d& pos, const CampType@ type, Region@ region = null) from "map_effects";
import Planet@ spawnPlanetSpec(const vec3d& point, const string& resourceSpec, bool distributeResource = true, double radius = 0.0, bool physics = true) from "map_effects";
import achievements;
from construction.Constructible import Constructible;
from Invasion.InvasionMap import increaseInvasionStrength;
import string getRandomFlagshipName() from "card_effects";
import string getRandomPlanetName() from "card_effects";
from util.design_export import resizeDesign;
#section all

//spawnorbitalinraidus

class SpawnOrbitalRange : EmpireTrigger {
	Document doc("Spawn an orbitalRange.");
	Argument type("Core", AT_OrbitalModule, doc="Type of orbital core to use.");
	Argument creep_owned("Creep Owned", AT_Boolean, "False", doc="Whether the orbital should be owned by the creeps.");
	Argument free("Free", AT_Boolean, "False", doc="Whether to make the orbital free of maintenance.");
	Argument add_status(AT_Status, EMPTY_DEFAULT, doc="Status effect to add to the orbital after it is created.");
	Argument set_home(AT_Boolean, "False", doc="Whether to set the orbital as a home object.");
	Argument offset(AT_Decimal, "0", doc="Offset from the object position to spawn.");


#section server
	void activate(Object@ obj, Empire@ emp) const override {
		auto@ def = getOrbitalModule(arguments[0].integer);
		vec3d pos;
		if(obj !is null) {
			pos = obj.position;
			if(obj.isRegion) {
				vec2d off = random2d(obj.radius * 0.4, obj.radius * 0.9);
				pos.x += off.x;
				pos.z += off.y;
			}
			else if(offset.decimal != 0) {
				vec2d off = random2d(offset.decimal*(randomd(0.5 , 1)));
				pos.x += off.x;
				pos.z += off.y;
			}
		}
		
		auto@ orb = createOrbital(pos, def, arguments[1].boolean ? Creeps : emp);
		if(arguments[2].boolean && !arguments[1].boolean)
			orb.makeFree();
		if(add_status.integer != -1)
			orb.addStatus(add_status.integer);
		if(set_home.boolean)
			@emp.HomeObj = orb;
	}

	void init(Empire& emp, any@ data) const override {}
	void postInit(Empire& emp, any@ data) const override { activate(null, emp); }
#section all
};
